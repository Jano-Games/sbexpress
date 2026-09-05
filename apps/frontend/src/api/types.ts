/** DTO shapes mirrored from the backend serializers. */

export type Role = 'admin' | 'hub'

export interface SessionUser {
  id: string
  name: string
  email: string
  role: Role
  roleLabel: string
}

export interface ShipmentRow {
  code: string
  supplierCode: string
  supplierName: string | null
  flightCode: string | null
  flightDate: string | null
  bookedKg: number
  weighedKg: number | null
  effectiveKg: number
  weightDelta: number | null
  description: string
  categories: string[]
  charge: number
  billAmount: number
  discountAmount: number
  paidAmount: number
  dueAmount: number
  status: string
  statusIndex: number
  statusLabel: string
  payStatus: string
  payMethod: string | null
  receiptStatus: string | null
  date: string
}

export interface ShipmentCosts {
  fareShare: number
  unpaidCosts: {cnFare:number;bdFare:number;customsTax:number}
  cnFare: number
  bdFare: number | null
  customsTax: number
  afterSalesFee: number
  extraLines: { category: string; reason: string; amount: number }[]
  profit: number
  profitPct: number | null
}

export interface ShipmentDetail extends ShipmentRow {
  chargeRate: number
  chargeCurrency: string
  pcsItems: PcsItem[]
  serials: string[]
  photosCount: number
  hasVideo: boolean
  lastMile: { courier: string; ref: string } | null
  flyerName: string | null
  packedAt: string | null
  packageCount: number
  trackToken: string | null
  log: { actor: string; message: string; at: string }[]
  flightSpaceKg: number | null
  costs: ShipmentCosts | null
  receipt: { method: string; amount: number; status: string; txnRef: string; date: string } | null
  invoice: { number: string; total: number; discount: number; issuedAt: string; updatedAt: string } | null
  payments: { method: string; amount: number; at: string }[]
}

export interface FlightLookup {
  found: boolean
  sample?: boolean
  flight?: {
    code: string
    airline: string | null
    from: { iata: string | null; city: string | null }
    to: { iata: string | null; city: string | null }
    depTime: string | null
    arrTime: string | null
    status: string | null
  }
}

export interface FlightLeg {
  code: string
  /** Departure date of this segment (overnight connections span two days). */
  date?: string | null
  fromIata: string
  fromCity: string
  toIata: string
  toCity: string
  depTime: string
  arrTime: string
}

export interface FlightSummary {
  ticketPaid: number
  ticketDue: number
  ticketRefundDue: number
  code: string
  date: string
  depTime: string
  arrTime: string
  via: string
  fare: number
  actualCost: number
  agencyShare: number
  settlements: {name:string;contribution:number;paidAmount:number}[]
  unallocatedFlyerPaid:number
  flyerPaidAmount: number
  flyerDue: number
  margin: number
  shipmentCosts: { cnTransport: number; courier: number; customs: number; other: number }
  totalShipmentCosts: number
  spaceKg: number
  mobiles: number
  laptops: number
  bookedKg: number
  leftKg: number
  status: string
  statusLabel: string
  flyers: string[]
  shipmentCount: number
  revenue: number
  legs: FlightLeg[]
}

export interface FlightDetail extends FlightSummary {
  flyerDetails: { name: string; bdPhone: string; initial: string }[]
  bookings: ShipmentRow[]
}

export interface Flyer {
  name: string
  firstName: string
  lastName: string
  cnPhone: string
  cnWhatsapp: boolean
  bdPhone: string
  bdWhatsapp: boolean
  university: string
  batch: string
  program: string
  wechat: string
  cnAddress: string
  homeAddress: string
  emergencyContact: string
  docStudentId: boolean
  docVisa: boolean
  docAdmission: boolean
}

export interface FlyerFlight {
  code: string
  date: string
  depTime: string
  arrTime: string
  spaceKg: number
  mobiles: number
  laptops: number
  bookedKg: number
  status: string
  statusLabel: string
}

export interface FlyerDetail extends Flyer {
  flights: FlyerFlight[]
  totalKg: number
  nextFlight: FlyerFlight | null
  lastFlight: FlyerFlight | null
}

export interface SupplierSummary {
  code: string
  name: string
  phone: string
  address: string
  terms: 'instant' | 'monthly'
  orderCount: number
  deliveredCount: number
  shippedKg: number
  billed: number
  paid: number
  balance: number
  /** Total invoice discounts given across this supplier's shipments. */
  discountTotal: number
}

export interface SupplierDetail extends SupplierSummary {
  orders: ShipmentRow[]
  invoices: { number: string; shipmentCode: string; total: number; discount: number; issuedAt: string }[]
  /** Recent money received across this supplier's shipments, newest first. */
  payments: { code: string; method: string; amount: number; at: string }[]
}

export interface InvoiceDoc {
  title: string
  number: string
  to: string
  lines: { label: string; amount: number }[]
  total: number
}

export interface ShipmentInvoice {
  number: string
  to: string
  shipmentCode: string
  lines: { label: string; amount: number }[]
  discount: number
  note: string
  total: number
  issuedAt: string
  updatedAt: string
}

export interface Notice {
  tag: 'WEIGHT' | 'FLIGHT' | 'DUE'
  text: string
}

export interface AdminOverview {
  /** "1 Sept – 4 Sept" — the current calendar week the KPIs cover. */
  weekLabel: string
  todayLabel: string
  rate: number
  cash: { bdt: number; cny: number; worth: number }
  received: number
  expenses: number
  refunded: number
  profit: number
  capitalReceived: number
  flyerReceivables: number
  payables: number
  net: number
  unpaid: number
  reviewCount: number
  openTodoCount: number
  nextFlight: { code: string; date: string; bookedKg: number; spaceKg: number } | null
  notices: Notice[]
  flights: {
    code: string
    date: string
    flyers: string[]
    bookedKg: number
    spaceKg: number
    status: string
    shipmentCount: number
  }[]
  activeShipments: ShipmentRow[]
}

export interface HubOverview {
  todayLabel: string
  atHubCount: number
  incoming: { kg: number; count: number; flightCode: string | null; flightDate: string | null }
  openTodoCount: number
  notices: Notice[]
  toProcess: ShipmentRow[]
}

export interface FinanceData {
  /** "week", "all", or a YYYY-MM month. */
  period: string
  periodLabel: string
  months: { value: string; label: string }[]
  rate: number
  cash: { bdt: number; cny: number; worth: number }
  invested: { bdt: number; cny: number; worth: number }
  received: number
  expenses: number
  net: number
  /** What customers still owe across every not-fully-paid shipment. */
  receivables: { total: number; count: number }
  /** Overall business results for the period (accrual, not cash). */
  results: {
    shipmentCount: number
    flightCount: number
    billing: number
    fares: number
    otherIncome: number
    earned: number
    tickets: number
    cnTransport: number
    bdTransport: number
    customs: number
    otherExpenses: number
    costs: number
    profit: number
    marginPct: number | null
  }
  paymentRows: { date: string; method: string; reference: string; shipmentCode: string | null; amount: number }[]
  ticketPayables: number
  ticketRefundReceivables: number
  costPayables: number
  flyerReceivables: number
  refunded: number
  customerCreditLiability: number
  refundRows: {reference:string;supplierCode:string;amount:number;accountName:string;reason:string;at:string}[]
  capitalReceived: number
  transfers: { reference: string; from: string; to: string; fromCurrency: string; toCurrency: string; amount: number; receivedAmount: number; note: string; at: string }[]
  accounts: { name: string; kind: string; currency: string; balance: number; bank?: {bankName:string;accountNumber:string;accountName:string;branch:string;district:string}|null; mobile?: {provider:string;number:string;label:string}|null }[]
  expenseRows: {
    date: string
    category: string
    amount: number
    reason: string
    shipmentCode: string | null
    flightCode: string | null
  }[]
  statements: { code: string; name: string; billed: number; paid: number; balance: number; shipmentCount: number }[]
}

export interface ReviewItem {
  code: string
  supplierCode: string
  supplierName: string
  method: string
  amount: number
  txnRef: string
  date: string
}

export interface Todo {
  id: string
  text: string
  auto: boolean
  done: boolean
}

export interface AppSettings {
  rate: number
  threshold: number
  investBdt: number
  investCny: number
  /** Default per-piece shipping rates by category, BDT. */
  pcsRates: Record<string, number>
}

export interface PcsItem {
  category: string
  count: number
  rate: number
  currency: 'BDT' | 'CNY'
  /** One entry per piece: model + serial/IMEI. */
  units: { model: string; serial: string }[]
}

export type PayMethodKind = 'mobile_banking' | 'bank_account'

export interface PayMethodRow {
  id: string
  kind: PayMethodKind
  provider: string
  label: string
  number: string
  note: string
  qrImage: string | null
  bankName: string
  accountNumber: string
  accountName: string
  branch: string
  district: string
  enabled: boolean
}

/** A pay method as the tracking page receives it — display name resolved. */
export interface TrackPayMethod extends Omit<PayMethodRow, 'enabled'> {
  name: string
}

export interface TrackInfo {
  expiresAt: string
  requestedAmount: number
  invoice: { number: string; lines: { label: string; amount: number }[]; discount: number; total: number; note: string; issuedAt: string } | null
  code: string
  statusLabel: string
  statusIndex: number
  contents: string
  kgLabel: string
  flightCode: string
  flightDate: string | null
  depTime: string | null
  arrTime: string | null
  via: string | null
  routeLabel: string
  updatedAt: string
  note: string
  due: number
  billLines: { label: string; amount: number }[]
  billSubtotal: number
  invoiceNumber: string | null
  totalBill: number
  paidSoFar: number
  discount: number
  showPay: boolean
  showPaid: boolean
  showPending: boolean
  payMethods: TrackPayMethod[]
}

