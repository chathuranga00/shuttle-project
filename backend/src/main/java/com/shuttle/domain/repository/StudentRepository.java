package com.shuttle.domain.repository;

import com.shuttle.domain.entity.Student;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

public interface StudentRepository extends JpaRepository<Student, Long>, JpaSpecificationExecutor<Student> {
    Optional<Student> findByStudentId(String studentId);
    Optional<Student> findByUserId(Long userId);
    boolean existsByStudentId(String studentId);
}
