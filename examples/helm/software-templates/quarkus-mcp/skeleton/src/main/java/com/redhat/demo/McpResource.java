package com.redhat.demo;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import java.util.Map;

@Path("/api/mcp")
public class McpResource {

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, Object> info() {
        return Map.of(
            "name", "${{values.name}}",
            "version", "1.0.0",
            "description", "${{values.description}}",
            "status", "running"
        );
    }

    @GET
    @Path("/tools")
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, Object> tools() {
        return Map.of(
            "tools", java.util.List.of(
                Map.of("name", "hello", "description", "Returns a greeting")
            )
        );
    }
}
