import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  ...(process.env.QUILT_STATIC_EXPORT === "1" ? { output: "export", trailingSlash: true } : {}),
  basePath: process.env.NEXT_PUBLIC_BASE_PATH ?? "",
};

export default nextConfig;
