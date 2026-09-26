package com.shuttle.admin.student;

import com.shuttle.domain.enums.UserStatus;
import jakarta.validation.constraints.NotNull;

public record UpdateStudentStatusRequest(
        @NotNull(message = "status is required")
        UserStatus status
) {}
