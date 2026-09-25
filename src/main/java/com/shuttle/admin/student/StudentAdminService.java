package com.shuttle.admin.student;

import com.shuttle.domain.entity.Student;
import com.shuttle.domain.enums.UserStatus;
import com.shuttle.domain.repository.StudentRepository;
import com.shuttle.domain.repository.UserRepository;
import com.shuttle.exception.ApiException;
import jakarta.persistence.criteria.Predicate;
import java.util.ArrayList;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class StudentAdminService {

    private final StudentRepository studentRepository;
    private final UserRepository userRepository;

    @Transactional(readOnly = true)
    public Page<StudentAdminResponse> listStudents(String search, UserStatus status, Pageable pageable) {
        Specification<Student> spec = (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();

            if (status != null) {
                predicates.add(cb.equal(root.get("user").get("status"), status));
            }

            if (search != null && !search.trim().isEmpty()) {
                String pattern = "%" + search.trim().toLowerCase() + "%";
                Predicate studentIdMatch = cb.like(cb.lower(root.get("studentId")), pattern);
                Predicate nameMatch = cb.like(cb.lower(root.get("user").get("fullName")), pattern);
                Predicate emailMatch = cb.like(cb.lower(root.get("user").get("email")), pattern);
                Predicate facultyMatch = cb.like(cb.lower(root.get("faculty")), pattern);
                predicates.add(cb.or(studentIdMatch, nameMatch, emailMatch, facultyMatch));
            }

            return cb.and(predicates.toArray(new Predicate[0]));
        };

        return studentRepository.findAll(spec, pageable).map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public StudentAdminResponse getById(Long id) {
        Student student = studentRepository.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "STUDENT_NOT_FOUND", "Student not found with ID: " + id));
        return toResponse(student);
    }

    @Transactional
    public StudentAdminResponse updateStudent(Long id, UpdateStudentRequest request) {
        Student student = studentRepository.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "STUDENT_NOT_FOUND", "Student not found with ID: " + id));

        if (request.fullName() != null && !request.fullName().isBlank()) {
            student.getUser().setFullName(request.fullName().trim());
        }
        if (request.phone() != null) {
            student.getUser().setPhone(request.phone().trim());
        }
        if (request.faculty() != null) {
            student.setFaculty(request.faculty().trim());
        }
        if (request.department() != null) {
            student.setDepartment(request.department().trim());
        }
        if (request.enrollmentYear() != null) {
            student.setEnrollmentYear(request.enrollmentYear());
        }

        userRepository.save(student.getUser());
        Student saved = studentRepository.save(student);
        return toResponse(saved);
    }

    @Transactional
    public StudentAdminResponse updateStatus(Long id, UserStatus newStatus) {
        Student student = studentRepository.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "STUDENT_NOT_FOUND", "Student not found with ID: " + id));

        student.getUser().setStatus(newStatus);
        userRepository.save(student.getUser());
        return toResponse(student);
    }

    @Transactional
    public void deleteStudent(Long id) {
        Student student = studentRepository.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "STUDENT_NOT_FOUND", "Student not found with ID: " + id));

        student.getUser().setStatus(UserStatus.INACTIVE);
        userRepository.save(student.getUser());
    }

    private StudentAdminResponse toResponse(Student s) {
        return new StudentAdminResponse(
                s.getId(),
                s.getUser().getId(),
                s.getStudentId(),
                s.getUser().getFullName(),
                s.getUser().getEmail(),
                s.getUser().getPhone(),
                s.getFaculty(),
                s.getDepartment(),
                s.getEnrollmentYear(),
                s.getUser().getStatus().name(),
                s.getCreatedAt()
        );
    }
}
