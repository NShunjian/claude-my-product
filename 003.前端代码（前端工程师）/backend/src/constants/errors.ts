export enum ErrorCode {
  INVALID_INPUT = 'INVALID_INPUT',
  USERNAME_TAKEN = 'USERNAME_TAKEN',
  INVALID_CREDENTIALS = 'INVALID_CREDENTIALS',
  MISSING_TOKEN = 'MISSING_TOKEN',
  INVALID_TOKEN = 'INVALID_TOKEN',
  RATE_LIMIT = 'RATE_LIMIT',
  NOT_FOUND = 'NOT_FOUND',
  FORBIDDEN = 'FORBIDDEN',
  CONFLICT = 'CONFLICT',
  WEAK_PASSWORD = 'WEAK_PASSWORD',
  INTERNAL = 'INTERNAL',
}

export class AppError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: ErrorCode,
    message: string,
  ) {
    super(message)
    this.name = 'AppError'
  }
}
