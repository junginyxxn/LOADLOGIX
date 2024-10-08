package org.ssafy.load.common.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import org.springframework.http.HttpStatus;

@Getter
@AllArgsConstructor
public enum ErrorCode {
    USER_NOT_FOUND(HttpStatus.NOT_FOUND, "User not founded"),
    INVALID_TOKEN(HttpStatus.UNAUTHORIZED, "Token is invalid"),
    EXPIRED_TOKEN(HttpStatus.UNAUTHORIZED, "Token is expired"),
    INVALID_REQUEST(HttpStatus.BAD_REQUEST, "Request is invalid"),
    INTERNAL_SERVER_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, "Internal Server error"),
    EMPTY_TABLE(HttpStatus.INTERNAL_SERVER_ERROR, "Empty db table"),
    CONVEYOR_NOT_FOUND(HttpStatus.NOT_FOUND, "Conveyor not founded"),
    USER_ALREADY_EXISTS(HttpStatus.CONFLICT, "User with given userId already exists"),
    ACCESS_DENIED(HttpStatus.FORBIDDEN, "Access denied: Insufficient permissions"),
    AREA_NOT_FOUND(HttpStatus.NOT_FOUND, "Area not founded"),
    BUILDING_NOT_FOUND(HttpStatus.NOT_FOUND, "Building not founded"),
    CAR_NOT_FOUND(HttpStatus.NOT_FOUND, "Car not founded"),
    INVALID_PK(HttpStatus.BAD_REQUEST,"PK is invalid"),
    INVALID_DATA(HttpStatus.BAD_REQUEST,"Invalid Data"),
    LOAD_TASK_NOT_FOUND(HttpStatus.NOT_FOUND, "Load task not founded"),
    INVALID_LOAD_TASK(HttpStatus.BAD_REQUEST,"Load task is invalid");

    final private HttpStatus status;
    final private String message;
}
