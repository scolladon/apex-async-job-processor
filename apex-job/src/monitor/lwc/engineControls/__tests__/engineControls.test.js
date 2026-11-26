import { createElement } from "lwc";
import EngineControls from "c/engineControls";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getEngineStatus from "@salesforce/apex/JobMonitorController.getEngineStatus";
import pauseEngine from "@salesforce/apex/JobMonitorController.pauseEngine";
import resumeEngine from "@salesforce/apex/JobMonitorController.resumeEngine";
import restartEngine from "@salesforce/apex/JobMonitorController.restartEngine";

jest.mock("@salesforce/apex/JobMonitorController.getEngineStatus", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/JobMonitorController.pauseEngine", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/JobMonitorController.resumeEngine", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/JobMonitorController.restartEngine", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/customPermission/Manage_Async_Job_Engine", () => ({ default: true }), { virtual: true });

const POLL_INTERVAL_MS = 5000;
const ShowToastEventName = "lightning__showtoast";
const HEALTHY_STATUS = { enabled: true, executorCount: 1, watcherScheduled: true };

const mount = () => {
  const element = createElement("c-engine-controls", { is: EngineControls });
  document.body.appendChild(element);
  return element;
};

const captureToasts = (element) => {
  const toasts = [];
  element.addEventListener(ShowToastEventName, (event) => toasts.push(event.detail));
  return toasts;
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

  it("givenEnabledEngine_whenToggled_thenPauseCalledAndSuccessToastDispatched", async () => {
    // Arrange
    pauseEngine.mockResolvedValue(true);
    const sut = mount();
    const toasts = captureToasts(sut);
    await jest.advanceTimersByTimeAsync(0);

    // Act
    sut.shadowRoot.querySelector("lightning-input").dispatchEvent(new CustomEvent("change"));
    await jest.advanceTimersByTimeAsync(0);

    // Assert
    expect(pauseEngine).toHaveBeenCalledTimes(1);
    expect(resumeEngine).not.toHaveBeenCalled();
    expect(sut.shadowRoot.querySelector("lightning-input").checked).toBe(false);
    expect(toasts).toEqual([{ title: "Engine paused", message: "Engine is now disabled.", variant: "success" }]);
  });

  it("givenDisabledEngine_whenToggled_thenResumeCalledAndEngineShownEnabled", async () => {
    // Arrange
    getEngineStatus.mockResolvedValue({ enabled: false, executorCount: 0, watcherScheduled: true });
    resumeEngine.mockResolvedValue(true);
    const sut = mount();
    const toasts = captureToasts(sut);
    await jest.advanceTimersByTimeAsync(0);

    // Act
    sut.shadowRoot.querySelector("lightning-input").dispatchEvent(new CustomEvent("change"));
    await jest.advanceTimersByTimeAsync(0);

    // Assert
    expect(resumeEngine).toHaveBeenCalledTimes(1);
    expect(pauseEngine).not.toHaveBeenCalled();
    expect(sut.shadowRoot.querySelector("lightning-input").checked).toBe(true);
    expect(toasts).toEqual([{ title: "Engine resumed", message: "Engine is now enabled.", variant: "success" }]);
  });

  it("givenPauseRejected_whenToggled_thenErrorToastCarriesApexMessage", async () => {
    // Arrange
    pauseEngine.mockRejectedValue({ body: { message: "Missing permission" } });
    const sut = mount();
    const toasts = captureToasts(sut);
    await jest.advanceTimersByTimeAsync(0);

    // Act
    sut.shadowRoot.querySelector("lightning-input").dispatchEvent(new CustomEvent("change"));
    await jest.advanceTimersByTimeAsync(0);

    // Assert
    expect(toasts).toEqual([{ title: "Pause failed", message: "Missing permission", variant: "error" }]);
    expect(sut.shadowRoot.querySelector("lightning-input").checked).toBe(true);
  });

  it("givenResumeRejectedWithPlainError_whenToggled_thenErrorToastCarriesErrorMessage", async () => {
    // Arrange
    getEngineStatus.mockResolvedValue({ enabled: false, executorCount: 0, watcherScheduled: true });
    resumeEngine.mockRejectedValue(new Error("boom"));
    const sut = mount();
    const toasts = captureToasts(sut);
    await jest.advanceTimersByTimeAsync(0);

    // Act
    sut.shadowRoot.querySelector("lightning-input").dispatchEvent(new CustomEvent("change"));
    await jest.advanceTimersByTimeAsync(0);

    // Assert
    expect(toasts).toEqual([{ title: "Resume failed", message: "boom", variant: "error" }]);
  });

  it("givenRestartClicked_whenApexResolves_thenRestartToastDispatched", async () => {
    // Arrange
    restartEngine.mockResolvedValue("707000000000001");
    const sut = mount();
    const toasts = captureToasts(sut);
    await jest.advanceTimersByTimeAsync(0);

    // Act
    sut.shadowRoot.querySelector("lightning-button").click();
    await jest.advanceTimersByTimeAsync(0);

    // Assert
    expect(restartEngine).toHaveBeenCalledTimes(1);
    expect(toasts).toEqual([{ title: "Restart requested", message: "Executor enqueued if not already running.", variant: "success" }]);
  });

  it("givenRestartRejectedWithoutMessage_whenClicked_thenErrorToastUsesFallbackMessage", async () => {
    // Arrange
    restartEngine.mockRejectedValue({});
    const sut = mount();
    const toasts = captureToasts(sut);
    await jest.advanceTimersByTimeAsync(0);

    // Act
    sut.shadowRoot.querySelector("lightning-button").click();
    await jest.advanceTimersByTimeAsync(0);

    // Assert
    expect(toasts).toEqual([{ title: "Restart failed", message: "Unexpected error", variant: "error" }]);
  });
});
