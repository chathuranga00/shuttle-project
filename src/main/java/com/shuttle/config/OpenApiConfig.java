package com.shuttle.config;

import io.swagger.v3.oas.annotations.enums.SecuritySchemeType;
import io.swagger.v3.oas.annotations.security.SecurityScheme;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@SecurityScheme(
        name = "bearerAuth",
        type = SecuritySchemeType.HTTP,
        scheme = "bearer",
        bearerFormat = "JWT",
        description = "Provide a valid JWT access token. Obtain one from POST /api/auth/login."
)
public class OpenApiConfig {

    @Bean
    public OpenAPI shuttleOpenApi() {
        return new OpenAPI()
                .info(new Info()
                        .title("Shuttle API")
                        .description("Campus shuttle management backend")
                        .version("0.0.1"));
    }
}
