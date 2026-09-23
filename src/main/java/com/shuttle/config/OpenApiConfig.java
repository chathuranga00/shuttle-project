package com.shuttle.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    @Bean
    OpenAPI shuttleOpenApi() {
        return new OpenAPI()
                .info(new Info()
                        .title("Shuttle API")
                        .description("Campus shuttle management backend")
                        .version("0.0.1"));
    }
}
