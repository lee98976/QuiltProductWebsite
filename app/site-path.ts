// Raw anchors and static assets do not receive next/link's automatic base path.
export function sitePath(path: string) {
  return `${process.env.NEXT_PUBLIC_BASE_PATH ?? ""}${path}`;
}
