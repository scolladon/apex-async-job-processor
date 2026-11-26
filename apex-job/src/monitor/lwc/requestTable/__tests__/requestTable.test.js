import { createElement } from "lwc";
import RequestTable from "c/requestTable";
import getJobRequestPage from "@salesforce/apex/JobMonitorController.getJobRequestPage";

jest.mock("@salesforce/apex/JobMonitorController.getJobRequestPage", () => ({ default: jest.fn() }), { virtual: true });

const POLL_INTERVAL_MS = 2000;

const mount = () => {
  const element = createElement("c-request-table", { is: RequestTable });
  document.body.appendChild(element);
  return element;
};

describe("c-request-table", () => {
  beforeEach(() => {
    jest.useFakeTimers();
    getJobRequestPage.mockResolvedValue([]);
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
    jest.useRealTimers();
  });

  it("givenConnected_whenIntervalElapses_thenOneApexCallPerInterval", async () => {
    // Arrange
    mount();

    // Act
    await jest.advanceTimersByTimeAsync(0);
    const callsAfterMount = getJobRequestPage.mock.calls.length;
    await jest.advanceTimersByTimeAsync(POLL_INTERVAL_MS);

    // Assert
    expect(callsAfterMount).toBe(1);
    expect(getJobRequestPage).toHaveBeenCalledTimes(2);
  });

  it("givenDisconnected_whenIntervalElapses_thenNoFurtherCall", async () => {
    // Arrange
    const sut = mount();
    await jest.advanceTimersByTimeAsync(0);

    // Act
    document.body.removeChild(sut);
    await jest.advanceTimersByTimeAsync(2 * POLL_INTERVAL_MS);

    // Assert
    expect(getJobRequestPage).toHaveBeenCalledTimes(1);
  });

  it("givenDisconnectedDuringInFlightCall_whenCallResolves_thenNoTimerArmed", async () => {
    // Arrange
    let resolveCall;
    getJobRequestPage.mockReturnValue(
      new Promise((resolve) => {
        resolveCall = resolve;
      })
    );
    const sut = mount();
    await jest.advanceTimersByTimeAsync(0);

    // Act
    document.body.removeChild(sut);
    resolveCall([]);
    await jest.advanceTimersByTimeAsync(0);

    // Assert
    expect(jest.getTimerCount()).toBe(0);
    expect(getJobRequestPage).toHaveBeenCalledTimes(1);
  });

  it("givenRejectedCall_whenIntervalElapses_thenErrorLoggedAndPollingResumes", async () => {
    // Arrange
    const failure = new Error("network");
    const consoleError = jest.spyOn(console, "error").mockImplementation(() => {});
    getJobRequestPage.mockRejectedValueOnce(failure);
    mount();

    // Act
    await jest.advanceTimersByTimeAsync(0);
    await jest.advanceTimersByTimeAsync(POLL_INTERVAL_MS);

    // Assert
    expect(getJobRequestPage).toHaveBeenCalledTimes(2);
    expect(consoleError).toHaveBeenCalledTimes(1);
    expect(consoleError).toHaveBeenCalledWith("requestTable: refresh failed", failure);
    consoleError.mockRestore();
  });
});
