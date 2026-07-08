export class BmuxError extends Error {
  constructor(message: string) {
    super(message);
    this.name = new.target.name;
  }
}

export class BmuxCommandError extends BmuxError {
  readonly commandId: unknown;
  readonly response: unknown;

  constructor(message: string, commandId?: unknown, response?: unknown) {
    super(message);
    this.commandId = commandId;
    this.response = response;
  }
}

export class BmuxConnectionError extends BmuxError {}
export class BmuxProtocolError extends BmuxError {}
export class BmuxTimeoutError extends BmuxError {}
