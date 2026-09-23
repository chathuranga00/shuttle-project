package com.shuttle.domain.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
@Table(
        name = "students",
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_students_user_id", columnNames = "user_id"),
                @UniqueConstraint(name = "uk_students_student_id", columnNames = "student_id")
        }
)
public class Student extends BaseEntity {

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    @Column(name = "student_id", nullable = false, unique = true, length = 50)
    private String studentId;

    @Column(length = 100)
    private String faculty;

    @Column(length = 100)
    private String department;

    @Column(name = "enrollment_year")
    private Integer enrollmentYear;
}
