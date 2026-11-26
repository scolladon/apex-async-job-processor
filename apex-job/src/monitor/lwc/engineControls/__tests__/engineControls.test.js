import { createElement } from "lwc";
import EngineControls from "c/engineControls";
import getEngineStatus from "@salesforce/apex/JobMonitorController.getEngineStatus";

jest.mock("@salesforce/apex/JobMonitorController.getEngineStatus", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/JobMonitorController.pauseEngine", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/JobMonitorController.resumeEngine", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/JobMonitorController.restartEngine", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/customPermission/Manage_Async_Job_Engine", () => ({ default: true }), { virtual: true });

const POLL_INTERVAL_MS = 5000;
const HEALTHY_STATUS = { enabled: true, executorCount: 1, watcherScheduled: true };

const mount = () => {
  const element = createElement("c-engine-controls", { is: EngineControls });
  document.body.appendChild(element);
  return element;
};

describe("c-engine-controls", () => {
  beforeEach(() => {
    jest.useFakeTimers();
    getEngineStatus.mockResolvedValue(HEALTHY_STATUS);
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
    const callsAfterMount = getEngineStatus.mock.calls.length;
    await jest.advanceTimersByTimeAsync(POLL_INTERVAL_MS);

    // Assert
    expect(callsAfterMount).toBe(1);
    expect(getEngineStatus).toHaveBeenCalledTimes(2);
  });

  it("givenDisconnected_whenIntervalElapses_thenNoFurtherCall", async () => {
    // Arrange
    const sut = mount();
    await jest.advanceTimersByTimeAsync(0);

    // Act
    document.body.removeChild(sut);
    await jest.advanceTimersByTimeAsync(2 * POLL_INTERVAL_MS);

    // Assert
    expect(getEngineStatus).toHaveBeenCalledTimes(1);
  });

  it("givenDisconnectedDuringInFlightCall_whenCallResolves_thenNoTimerArmed", async () => {
    // Arrange
    let resolveCall;
    getEngineStatus.mockReturnValue(
      new Promise((resolve) => {
        resolveCall = resolve;
      })
    );
    const sut = mount();
    await jest.advanceTimersByTimeAsync(0);

    // Act
    document.body.removeChild(sut);
    resolveCall(HEALTHY_STATUS);
    await jest.advanceTimersByTimeAsync(0);

    // Assert
    expect(jest.getTimerCount()).toBe(0);
    expect(getEngineStatus).toHaveBeenCalledTimes(1);
  });

  it("givenRejectedCall_whenIntervalElapses_thenErrorLoggedAndPollingResumes", async () => {
    // Arrange
    const failure = new Error("network");
    const consoleError = jest.spyOn(console, "error").mockImplementation(() => {});
    getEngineStatus.mockRejectedValueOnce(failure);
    mount();

    // Act
    await jest.advanceTimersByTimeAsync(0);
    await jest.advanceTimersByTimeAsync(POLL_INTERVAL_MS);

    // Assert
    expect(getEngineStatus).toHaveBeenCalledTimes(2);
    expect(consoleError).toHaveBeenCalledTimes(1);
    expect(consoleError).toHaveBeenCalledWith("engineControls: refresh failed", failure);
    consoleError.mockRestore();
  });

  it("givenEngineStatus_whenRefreshed_thenRendersEachValue", async () => {
    // Arrange
    getEngineStatus.mockResolvedValue({ enabled: true, executorCount: 3, watcherScheduled: false });
    const element = mount();

    // Act
    await jest.advanceTimersByTimeAsync(0);

    // Assert
    const toggle = element.shadowRoot.querySelector("lightning-input");
    const values = [...element.shadowRoot.querySelectorAll("b")].map((node) => node.textContent);
    expect(toggle.checked).toBe(true);
    expect(values).toEqual(["Not Scheduled", "3"]);
  });
});
