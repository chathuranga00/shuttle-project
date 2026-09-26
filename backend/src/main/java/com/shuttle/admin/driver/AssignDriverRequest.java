package com.shuttle.admin.driver;

import jakarta.validation.constraints.NotNull;

public record AssignDriverRequest(
        @NotNull Long busId,
                 Long routeId   // optional
) {}
