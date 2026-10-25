import type { FlightLeg } from "@/api/types";

/** Reviewable flights built from an e-ticket. Nothing here talks to the API. */

export type Direction = "to_bangladesh" | "from_bangladesh" | "other";

export interface TicketImport {
  ticket: {
    agency: string | null;
    passenger: string | null;
    pnr: string | null;
    ticketNumber: string | null;
    issuedOn: string | null;
  };
  flyerMatches: { name: string; score: number }[];
  journeys: { direction: Direction; date: string; legs: FlightLeg[] }[];
}

export type LegField =
  | "code"
  | "date"
  | "fromIata"
  | "fromCity"
  | "toIata"
  | "toCity"
  | "depTime"
  | "arrTime";

export interface EditableLeg extends Record<LegField, string> {
  key: string;
}

export interface Draft {
  key: string;
  direction: Direction;
  legs: EditableLeg[];
  spaceKg: string;
  mobiles: string;
  laptops: string;
  actualCost: string;
  agencyShare: string;
  saved: boolean;
  error: string;
}

export const DIRECTION_LABEL: Record<Direction, string> = {
  to_bangladesh: "To Bangladesh",
  from_bangladesh: "From Bangladesh",
  other: "Other journey",
};

export const LEG_FIELDS: [LegField, string, "text" | "date" | "time"][] = [
  ["code", "Flight number", "text"],
  ["date", "Departure date", "date"],
  ["fromIata", "From (airport code)", "text"],
  ["toIata", "To (airport code)", "text"],
  ["fromCity", "From city", "text"],
  ["toCity", "To city", "text"],
  ["depTime", "Departs", "time"],
  ["arrTime", "Arrives", "time"],
];

const TITLES = new Set(["MR", "MRS", "MS", "MISS", "MSTR", "MD", "MST", "SD", "DR"]);

/** "KHAN / MD ARIF HOSSAIN SD" → "Arif Hossain Khan" for the flyer form. */
export function flyerPrefill(passenger: string | null): string | undefined {
  if (!passenger) return undefined;
  const [surname = "", given = ""] = passenger.split("/").map((part) => part.trim());
  const words = [...given.split(/\s+/), ...surname.split(/\s+/)]
    .filter((word) => word && !TITLES.has(word.toUpperCase()))
    .map((word) => word.charAt(0) + word.slice(1).toLowerCase());
  return words.join(" ") || undefined;
}

let keySeed = 0;
const nextKey = () => `k${(keySeed += 1)}`;

export function draftsFrom(result: TicketImport): Draft[] {
  return result.journeys.map((journey) => ({
    key: nextKey(),
    direction: journey.direction,
    legs: journey.legs.map((leg) => ({
      key: nextKey(),
      code: leg.code,
      date: leg.date ?? journey.date,
      fromIata: leg.fromIata,
      fromCity: leg.fromCity,
      toIata: leg.toIata,
      toCity: leg.toCity,
      depTime: leg.depTime,
      arrTime: leg.arrTime,
    })),
    spaceKg: "44",
    mobiles: "2",
    laptops: "1",
    actualCost: "",
    agencyShare: "",
    saved: false,
    error: "",
  }));
}

/** The first thing to fix before this draft can be saved, or "". */
export function draftProblem(draft: Draft): string {
  if (!draft.legs.length) return "Add at least one segment.";
  for (const leg of draft.legs) {
    if (!/^[A-Z0-9]{2}\d{1,4}$/.test(leg.code)) return `Check flight number “${leg.code}”.`;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(leg.date)) return `Set the date for ${leg.code}.`;
    if (!/^[A-Z]{3}$/.test(leg.fromIata) || !/^[A-Z]{3}$/.test(leg.toIata))
      return `Use three-letter airport codes for ${leg.code}.`;
    if (!/^\d{2}:\d{2}$/.test(leg.depTime) || !/^\d{2}:\d{2}$/.test(leg.arrTime))
      return `Set departure and arrival times for ${leg.code}.`;
  }
  const cost = Number(draft.actualCost || 0);
  const share = Number(draft.agencyShare || 0);
  if (!(cost >= 0) || !(share >= 0)) return "Ticket amounts must be zero or more.";
  if (share > cost) return "Agency share cannot exceed the ticket cost.";
  return "";
}

export const routeOf = (legs: EditableLeg[]) =>
  legs.length
    ? [legs[0]!.fromIata || legs[0]!.fromCity, ...legs.map((leg) => leg.toIata || leg.toCity)].join(" → ")
    : "No segments";

/** POST /flights body for one reviewed draft. Amounts are BDT. */
export function flightBody(draft: Draft, flyer: string) {
  const first = draft.legs[0]!;
  const last = draft.legs[draft.legs.length - 1]!;
  return {
    code: draft.legs.map((leg) => leg.code).join("+"),
    date: first.date,
    depTime: first.depTime,
    arrTime: last.arrTime,
    flyerNames: [flyer],
    actualCost: Number(draft.actualCost || 0),
    agencyShare: Number(draft.agencyShare || 0),
    spaceKg: parseInt(draft.spaceKg) || 0,
    mobiles: parseInt(draft.mobiles) || 0,
    laptops: parseInt(draft.laptops) || 0,
    legs: draft.legs.map((leg) => ({
      source: "ticket",
      code: leg.code,
      date: leg.date,
      fromIata: leg.fromIata,
      fromCity: leg.fromCity,
      toIata: leg.toIata,
      toCity: leg.toCity,
      depTime: leg.depTime,
      arrTime: leg.arrTime,
    })),
  };
}
