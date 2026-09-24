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

@Configuration
@EnableMethodSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final UserDetailsServiceImpl userDetailsService;
    private final JwtAuthenticationFilter jwtAuthenticationFilter;
    private final RateLimitFilter rateLimitFilter;
    private final AuthEntryPoint authEntryPoint;

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
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                .csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(session ->
                        session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .exceptionHandling(ex -> ex
                        .authenticationEntryPoint(authEntryPoint))
                .authorizeHttpRequests(auth -> auth
                        // Public endpoints
                        .requestMatchers("/api/auth/**").permitAll()
                        .requestMatchers("/v3/api-docs/**", "/swagger-ui/**", "/swagger-ui.html").permitAll()

                        // Admin only
                        .requestMatchers("/api/admin/**").hasRole("ADMIN")

                        // Driver only
                        .requestMatchers("/api/driver/**").hasRole("DRIVER")
                        .requestMatchers(HttpMethod.POST, "/api/trips/*/start").hasRole("DRIVER")
                        .requestMatchers(HttpMethod.POST, "/api/trips/*/end").hasRole("DRIVER")
                        .requestMatchers(HttpMethod.POST, "/api/trips/*/board").hasRole("DRIVER")

                        // Student endpoints
                        .requestMatchers("/api/students/**").hasRole("STUDENT")

                        // Boarding — students only
                        .requestMatchers("/api/boarding/**").hasRole("STUDENT")

                        // Monthly pass — students only
                        .requestMatchers("/api/monthly-pass/**").hasRole("STUDENT")

                        // Card verification — driver or admin only
                        .requestMatchers(HttpMethod.POST, "/api/cards/verify").hasAnyRole("DRIVER", "ADMIN")

                        // Public route information — any authenticated user
                        .requestMatchers(HttpMethod.GET, "/api/routes/**").authenticated()

                        // Everything else requires authentication
                        .anyRequest().authenticated()
                )
                .authenticationProvider(authenticationProvider())
                .addFilterBefore(rateLimitFilter, UsernamePasswordAuthenticationFilter.class)
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}
