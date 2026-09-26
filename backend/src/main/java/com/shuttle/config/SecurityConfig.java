package com.shuttle.config;

import com.shuttle.security.AuthEntryPoint;
import com.shuttle.security.JwtAuthenticationFilter;
import com.shuttle.security.RateLimitFilter;
import com.shuttle.security.UserDetailsServiceImpl;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.AuthenticationProvider;
import org.springframework.security.authentication.dao.DaoAuthenticationProvider;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

import java.util.List;
import org.springframework.security.config.Customizer;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

@Configuration
@EnableMethodSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final UserDetailsServiceImpl userDetailsService;
    private final JwtAuthenticationFilter jwtAuthenticationFilter;
    private final RateLimitFilter rateLimitFilter;
    private final AuthEntryPoint authEntryPoint;

    @org.springframework.beans.factory.annotation.Value("${app.cors.allowed-origins:http://localhost:5173,http://localhost:3000}")
    private List<String> allowedOrigins;

    @org.springframework.beans.factory.annotation.Value("${app.cors.allowed-origin-patterns:http://localhost:*,http://127.0.0.1:*}")
    private List<String> allowedOriginPatterns;

    @org.springframework.beans.factory.annotation.Value("${spring.profiles.active:dev}")
    private String activeProfile;

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public AuthenticationProvider authenticationProvider() {
        DaoAuthenticationProvider provider = new DaoAuthenticationProvider();
        provider.setUserDetailsService(userDetailsService);
        provider.setPasswordEncoder(passwordEncoder());
        return provider;
    }

    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration config) throws Exception {
        return config.getAuthenticationManager();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();
        if ("prod".equalsIgnoreCase(activeProfile)) {
            configuration.setAllowedOrigins(allowedOrigins);
        } else {
            configuration.setAllowedOriginPatterns(allowedOriginPatterns);
        }
        configuration.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"));
        configuration.setAllowedHeaders(List.of("Authorization", "Content-Type", "X-Requested-With", "Accept", "Origin", "Access-Control-Request-Method", "Access-Control-Request-Headers"));
        configuration.setExposedHeaders(List.of("Content-Disposition", "X-QR-Payload"));
        configuration.setAllowCredentials(true);
        configuration.setMaxAge(3600L);
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                .cors(Customizer.withDefaults())
                .csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(session ->
                        session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .exceptionHandling(ex -> ex
                        .authenticationEntryPoint(authEntryPoint))
                .headers(headers -> headers
                        .frameOptions(frame -> frame.deny())
                        .contentTypeOptions(Customizer.withDefaults())
                        .xssProtection(Customizer.withDefaults())
                        .contentSecurityPolicy(csp -> csp.policyDirectives("default-src 'self'; frame-ancestors 'none'; object-src 'none';"))
                        .httpStrictTransportSecurity(hsts -> hsts
                                .includeSubDomains(true)
                                .maxAgeInSeconds(31536000)
                                .preload(true)
                        )
                );

        if ("prod".equalsIgnoreCase(activeProfile)) {
            http.requiresChannel(channel -> channel.anyRequest().requiresSecure());
        }

        http.authorizeHttpRequests(auth -> auth
                .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                // Public endpoints
                .requestMatchers("/api/auth/**").permitAll()
                .requestMatchers("/v3/api-docs/**", "/swagger-ui/**", "/swagger-ui.html").permitAll()
                .requestMatchers("/actuator/health", "/actuator/info").permitAll()

                // WebSocket STOMP endpoint for live tracking
                .requestMatchers("/ws/**", "/ws").permitAll()

                // Live bus location & active trips — any authenticated user (student, driver, admin)
                .requestMatchers(HttpMethod.GET, "/api/trips/*/location").authenticated()
                .requestMatchers(HttpMethod.GET, "/api/trips/active").authenticated()

                // Admin only
                .requestMatchers("/api/admin/**").hasRole("ADMIN")

                // Driver only
                .requestMatchers("/api/driver/**").hasRole("DRIVER")
                .requestMatchers("/api/trips/**").hasRole("DRIVER")

                // Student endpoints
                .requestMatchers("/api/students/**").hasRole("STUDENT")

                // Boarding — students only
                .requestMatchers("/api/boarding/**").hasRole("STUDENT")

                // Monthly pass — students only
                .requestMatchers("/api/monthly-pass/**").hasRole("STUDENT")

                // Wallet — students only (drivers must NOT access payment processing)
                .requestMatchers("/api/wallet/**").hasRole("STUDENT")

                // Payment webhook — public (gateway calls this; signature verified inside)
                .requestMatchers("/api/payment/webhook").permitAll()
                .requestMatchers("/api/payment/mock-callback").permitAll()
                // Payment status poll + history — students or admin (drivers must NOT access payment processing)
                .requestMatchers("/api/payment/**").hasAnyRole("STUDENT", "ADMIN")

                // Card verification — driver or admin only
                .requestMatchers(HttpMethod.POST, "/api/cards/verify").hasAnyRole("DRIVER", "ADMIN")

                // Public route information — any authenticated user
                .requestMatchers(HttpMethod.GET, "/api/routes/**").authenticated()

                // Notifications and devices — any authenticated user
                .requestMatchers("/api/notifications/**").authenticated()
                .requestMatchers("/api/devices/**").authenticated()

                // Everything else requires authentication
                .anyRequest().authenticated()
        )
        .authenticationProvider(authenticationProvider())
        .addFilterBefore(rateLimitFilter, UsernamePasswordAuthenticationFilter.class)
        .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}
