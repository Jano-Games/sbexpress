/**
 * Client upload preparation. The API rejects HEIC, so photos are converted
 * to JPEG and compressed to at most 2000px at quality 0.80 before upload.
 * The server re-encodes again to strip metadata. There is no antivirus scan.
 */

export const IMAGE_MAX_EDGE = 2000;
export const IMAGE_JPEG_QUALITY = 0.8;

export type ImageKind = "jpeg" | "png" | "webp" | "heic" | "other";

export function fittedSize(
  width: number,
  height: number,
  maxEdge = IMAGE_MAX_EDGE,
): { width: number; height: number } {
  const longest = Math.max(width, height);
  if (!longest || longest <= maxEdge) return { width, height };
  const scale = maxEdge / longest;
  return {
    width: Math.max(1, Math.round(width * scale)),
    height: Math.max(1, Math.round(height * scale)),
  };
}

const ascii = (bytes: Uint8Array, start: number, end: number) =>
  String.fromCharCode(...bytes.slice(start, end));

export function sniffImage(bytes: Uint8Array): ImageKind {
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return "jpeg";
  if (bytes.length >= 8 && [137, 80, 78, 71, 13, 10, 26, 10].every((value, index) => bytes[index] === value)) return "png";
  if (bytes.length >= 12 && ascii(bytes, 0, 4) === "RIFF" && ascii(bytes, 8, 12) === "WEBP") return "webp";
  if (bytes.length >= 12 && ascii(bytes, 4, 8) === "ftyp") {
    const brand = ascii(bytes, 8, 12).toLowerCase();
    if (["heic", "heix", "hevc", "hevx", "mif1", "msf1", "heim", "heis"].includes(brand)) return "heic";
  }
  return "other";
}

export function isHeicName(name: string, type: string): boolean {
  return /image\/hei[cf]/i.test(type) || /\.hei[cf]$/i.test(name);
}

export function safeFileName(name: string, extension: string): string {
  const ext = extension.replace(/^\./, "");
  const base = name.replace(/\.[^.]+$/, "").replace(/[^\w.-]+/g, "-").replace(/^-+|-+$/g, "") || "photo";
  const max = 180 - ext.length - 1;
  return `${base.slice(0, Math.max(1, max))}.${ext}`;
}

export type UploadPlan =
  | { kind: "reencode" }
  | { kind: "heic" }
  | { kind: "pdf" }
  | { kind: "video" }
  | { kind: "reject"; message: string };

export function planUpload(input: {
  name: string;
  type: string;
  size: number;
  header: Uint8Array;
  allowPdf: boolean;
  allowVideo: boolean;
}): UploadPlan {
  if (!input.size) return { kind: "reject", message: "Choose a non-empty file." };
  const sniffed = sniffImage(input.header);
  if (sniffed === "jpeg" || sniffed === "png" || sniffed === "webp") return { kind: "reencode" };
  if (sniffed === "heic" || (sniffed === "other" && isHeicName(input.name, input.type))) return { kind: "heic" };
  if (input.allowPdf && (input.type === "application/pdf" || ascii(input.header, 0, 5) === "%PDF-")) return { kind: "pdf" };
  if (input.allowVideo && (input.type === "video/mp4" || input.type === "video/webm")) return { kind: "video" };
  if (input.type === "image/svg+xml" || /\.svg$/i.test(input.name)) {
    return { kind: "reject", message: "SVG files are not accepted. Use a JPEG, PNG or WebP image." };
  }
  const kinds = input.allowPdf
    ? "JPEG, PNG, WebP, HEIC or PDF"
    : input.allowVideo
      ? "JPEG, PNG, WebP, HEIC, MP4 or WebM"
      : "JPEG, PNG, WebP or HEIC";
  return { kind: "reject", message: `Choose a ${kinds} file.` };
}

export function describeUploadError(error: unknown): string {
  const status = error && typeof error === "object" && "status" in error && typeof error.status === "number"
    ? error.status
    : undefined;
  const message = error instanceof Error ? error.message : "";
  if (status === 503 || /not configured/i.test(message)) {
    return "File storage is not configured yet. An administrator needs to finish storage setup before this upload can work.";
  }
  if (status === 429 || /too many uploads/i.test(message)) {
    return "Too many uploads in a short time. Wait a minute and try again.";
  }
  if (/expired/i.test(message)) {
    return "The upload reservation expired before it could finish. Your file is still selected; try again.";
  }
  if (error instanceof TypeError || /failed to fetch|networkerror|load failed|network request failed/i.test(message)) {
    return "The upload did not reach storage. This is usually a connection problem or a storage CORS setting. Your file is still selected; try again.";
  }
  if (status) {
    return message && !/^request failed/i.test(message)
      ? `Upload failed (${status}): ${message}`
      : `Upload failed (${status}). Your file is still selected; try again.`;
  }
  if (message) return message;
  return "Upload failed. Your file is still selected; try again.";
}

function statusOf(error: unknown): number | undefined {
  return error && typeof error === "object" && "status" in error && typeof error.status === "number"
    ? error.status
    : undefined;
}

async function convertHeic(file: Blob): Promise<Blob> {
  try {
    const bitmap = await createImageBitmap(file);
    bitmap.close();
    return file;
  } catch {
    // The browser could not decode this HEIC file. Fall through to the converter.
  }
  try {
    const loaded = await import("heic2any");
    const result = await loaded.default({ blob: file, toType: "image/jpeg", quality: IMAGE_JPEG_QUALITY });
    const blob = Array.isArray(result) ? result[0] : result;
    if (!blob) throw new Error("empty");
    return blob;
  } catch {
    throw new Error("This HEIC photo could not be converted in this browser. Export it as JPEG and try again.");
  }
}

async function reencodeImageFile(blob: Blob, name: string): Promise<File> {
  const bitmap = await createImageBitmap(blob);
  try {
    const size = fittedSize(bitmap.width, bitmap.height);
    const canvas = document.createElement("canvas");
    canvas.width = size.width;
    canvas.height = size.height;
    const context = canvas.getContext("2d");
    if (!context) throw new Error("This browser could not prepare the image.");
    context.drawImage(bitmap, 0, 0, size.width, size.height);
    const output = await new Promise<Blob | null>((resolve) => {
      canvas.toBlob(resolve, "image/jpeg", IMAGE_JPEG_QUALITY);
    });
    if (!output) throw new Error("This image could not be compressed.");
    return new File([output], name, { type: "image/jpeg", lastModified: Date.now() });
  } finally {
    bitmap.close();
  }
}

export async function prepareUploadFile(
  file: File,
  options: { maxBytes: number; allowPdf?: boolean; allowVideo?: boolean; videoMaxBytes?: number },
): Promise<File> {
  const header = new Uint8Array(await file.slice(0, 32).arrayBuffer());
  const plan = planUpload({
    name: file.name,
    type: file.type,
    size: file.size,
    header,
    allowPdf: Boolean(options.allowPdf),
    allowVideo: Boolean(options.allowVideo),
  });
  switch (plan.kind) {
    case "reject":
      throw new Error(plan.message);
    case "pdf":
      if (file.name.length > 180) throw new Error("Shorten the file name to 180 characters or fewer.");
      if (file.size > options.maxBytes) throw new Error(`Choose a file under ${Math.round(options.maxBytes / 1048576)} MB.`);
      return file;
    case "video": {
      const limit = options.videoMaxBytes ?? 100 * 1024 * 1024;
      if (file.name.length > 180) throw new Error("Shorten the file name to 180 characters or fewer.");
      if (file.size > limit) throw new Error(`Choose a video under ${Math.round(limit / 1048576)} MB.`);
      return file;
    }
    case "heic":
    case "reencode": {
      const source = plan.kind === "heic" ? await convertHeic(file) : file;
      const prepared = await reencodeImageFile(source, safeFileName(file.name, "jpg"));
      if (prepared.size > options.maxBytes) {
        throw new Error(`This image is still over ${Math.max(1, Math.round(options.maxBytes / 1048576))} MB after compression. Choose a smaller photo.`);
      }
      return prepared;
    }
    default: {
      const unreachable: never = plan;
      return unreachable;
    }
  }
}

export async function transferUpload(options: {
  file: File;
  reserve: (file: File) => Promise<{ reference: string; uploadUrl: string }>;
  complete: (reference: string) => Promise<unknown>;
  fetchImpl?: typeof fetch;
}): Promise<string> {
  const fetchImpl = options.fetchImpl ?? fetch;
  let lastError: unknown;
  for (let attempt = 0; attempt < 2; attempt += 1) {
    let reservation: { reference: string; uploadUrl: string };
    try {
      reservation = await options.reserve(options.file);
    } catch (error) {
      lastError = error;
      const status = statusOf(error);
      if (status && status < 500 && status !== 429) break;
      continue;
    }
    try {
      const response = await fetchImpl(reservation.uploadUrl, {
        method: "PUT",
        headers: { "Content-Type": options.file.type },
        body: options.file,
      });
      if (!response.ok) {
        throw Object.assign(new Error(`Upload failed (${response.status})`), { status: response.status });
      }
    } catch (error) {
      lastError = error;
      continue;
    }
    try {
      await options.complete(reservation.reference);
      return reservation.reference;
    } catch (error) {
      const expired = error instanceof Error && /expired/i.test(error.message);
      if (!expired) {
        try {
          await options.complete(reservation.reference);
          return reservation.reference;
        } catch (again) {
          lastError = again;
          break;
        }
      }
      lastError = error;
    }
  }
  throw new Error(describeUploadError(lastError));
}

/** A selected screenshot is optional. A failed upload must not stop the payment. */
export async function optionalScreenshotReference(options: {
  hasFile: boolean;
  upload: () => Promise<string | undefined>;
  confirmWithoutScreenshot: () => boolean;
}): Promise<string | undefined> {
  if (!options.hasFile) return undefined;
  try {
    return await options.upload();
  } catch (error) {
    if (options.confirmWithoutScreenshot()) return undefined;
    throw error;
  }
}
