package com.eventflow;

import org.junit.jupiter.api.Test;
import org.yaml.snakeyaml.Yaml;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class OpenApiYamlTest {

    @Test
    void apifoxOpenApiFileIsValidYaml() throws IOException {
        try (InputStream input = Files.newInputStream(Paths.get("apifox-openapi.yaml"))) {
            Map<String, Object> document = new Yaml().load(input);
            assertEquals("3.0.3", document.get("openapi"));
            assertTrue(document.containsKey("paths"));
        }
    }
}
