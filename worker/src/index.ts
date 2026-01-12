/**
 * XET Proxy Server - Cloudflare Workers Container
 * 
 * This Worker provides an HTTP interface to the XET protocol implementation
 * running in a container. It handles routing, authentication, and request
 * forwarding to the containerized Rust/Zig backend.
 */

import { Container, getContainer } from "@cloudflare/containers";

/**
 * Environment bindings for the Worker
 */
interface Env {
  XET_PROXY: DurableObjectNamespace<XetProxyContainer>;
  // HF_TOKEN is optional here - can be passed via Authorization header instead
  HF_TOKEN?: string;
}

/**
 * Container class that manages the XET Proxy instance
 */
export class XetProxyContainer extends Container<Env> {
  // The Rust proxy server listens on port 8080
  defaultPort = 8080;
  
  // Keep container alive for 10 minutes after last request
  // This helps with subsequent requests to avoid cold starts
  sleepAfter = "10m";
  
  // Allow internet access for downloading from HuggingFace
  enableInternet = true;

  // Environment variables to pass to the container
  envVars = {
    PORT: "8080",
    ZIG_BIN_PATH: "/usr/local/bin/xet-download",
  };

  /**
   * Lifecycle hook: called when container successfully starts
   */
  override onStart() {
    console.log("XET Proxy container started successfully");
  }

  /**
   * Lifecycle hook: called when container stops
   */
  override onStop(stopParams: { exitCode?: number; reason?: string }) {
    if (stopParams.exitCode === 0) {
      console.log("XET Proxy container stopped gracefully");
    } else {
      console.log(`XET Proxy container stopped with exit code: ${stopParams.exitCode}`);
    }
    console.log(`Stop reason: ${stopParams.reason}`);
  }

  /**
   * Lifecycle hook: called when container encounters an error
   */
  override onError(error: unknown) {
    console.error("XET Proxy container error:", error);
  }
}

/**
 * Worker fetch handler - routes all requests to the container
 */
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      // Get or create the default container instance
      const container = getContainer(env.XET_PROXY);

      // Forward all headers (including Authorization) to the container
      const modifiedRequest = new Request(request.url, {
        method: request.method,
        headers: request.headers,
        body: request.body,
      });

      // Forward the request to the container
      return await container.fetch(modifiedRequest);
    } catch (error) {
      console.error("Worker error:", error);
      
      return new Response(
        JSON.stringify({
          error: "Internal server error",
          message: error instanceof Error ? error.message : String(error),
        }),
        {
          status: 500,
          headers: {
            "Content-Type": "application/json",
          },
        }
      );
    }
  },
} satisfies ExportedHandler<Env>;
