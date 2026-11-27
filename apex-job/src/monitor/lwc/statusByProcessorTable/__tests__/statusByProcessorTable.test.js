import { createElement } from "lwc";
import StatusByProcessorTable from "c/statusByProcessorTable";
import getStatusByProcessor from "@salesforce/apex/JobMonitorController.getStatusByProcessor";
import getJobDescriptionInfos from "@salesforce/apex/JobMonitorController.getJobDescriptionInfos";

jest.mock("@salesforce/apex/JobMonitorController.getStatusByProcessor", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/JobMonitorController.getJobDescriptionInfos", () => ({ default: jest.fn() }), { virtual: true });

const POLL_INTERVAL_MS = 5000;

const mount = () => {
  const element = createElement("c-status-by-processor-table", { is: StatusByProcessorTable });
  document.body.appendChild(element);
  return element;
};

const datatable = (sut) => sut.shadowRoot.querySelector("lightning-datatable");

describe("c-status-by-processor-table", () => {
  let clientRects;

  beforeEach(() => {
    jest.useFakeTimers();
    clientRects = jest.spyOn(Element.prototype, "getClientRects").mockReturnValue([{}]);
    getStatusByProcessor.mockResolvedValue([]);
    getJobDescriptionInfos.mockResolvedValue([]);
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
    clientRects.mockRestore();
    jest.useRealTimers();
  });

  it("givenGroupsAndDescriptionInfos_whenRefreshed_thenRowCarriesDescriptionStatistics", async () => {
    // Arrange
    getStatusByProcessor.mockResolvedValue([{ nbRows: 3, status: "PENDING", processorId: "a01" }]);
    getJobDescriptionInfos.mockResolvedValue([
      {
        Id: "a01",
        ProcessorName__c: "MyProcessor",
        MaxChunkSize__c: 40,
        SmallestFailingChunk__c: 60,
        SuccessStreak__c: 5,
        ConsecutiveFailures__c: 2,
        LastExecutionDateTime__c: "2026-11-26T10:00:00.000Z",
        KillBackoffUntil__c: "2026-11-26T10:05:00.000Z",
        MaxExecutionsPerMinute__c: 10,
        ExecutionsInCurrentWindow__c: 4
      }
    ]);

    // Act
    const sut = mount();
    await jest.advanceTimersByTimeAsync(0);

    // Assert
    expect(getJobDescriptionInfos).toHaveBeenCalledWith({ jobDescriptionIds: ["a01"] });
    expect(datatable(sut).data).toEqual([
      expect.objectContaining({
        nbRows: 3,
        status: "PENDING",
        processorId: "a01",
        processorUrl: "/a01",
        processorName: "MyProcessor",
        maxBulk: 40,
        smallestFailingChunk: 60,
        successStreak: 5,
        consecutiveFailure: 2,
        lastExecutionDateTime: "2026-11-26T10:00:00.000Z",
        killBackoffUntil: "2026-11-26T10:05:00.000Z",
        maxExecutionsPerMinute: 10,
        executionsInCurrentWindow: 4
      })
    ]);
  });

  it("givenColumns_whenRendered_thenNoNbTryNorNextExecAndLastExecIsDateTime", async () => {
    // Arrange
    const sut = mount();

    // Act
    await jest.advanceTimersByTimeAsync(0);
    const columns = datatable(sut).columns;

    // Assert
    const labels = columns.map((column) => column.label);
    expect(labels).not.toContain("Nb Try");
    expect(labels).not.toContain("Next Exec");
    const lastExec = columns.find((column) => column.fieldName === "lastExecutionDateTime");
    expect(lastExec.type).toBe("date");
    expect(lastExec.typeAttributes).toEqual(expect.objectContaining({ year: "numeric", month: "short", day: "2-digit", hour: "2-digit", minute: "2-digit", second: "2-digit" }));
  });

  it("givenColumns_whenRendered_thenKillBackoffUntilIsDateTimeAfterConsecutiveFailure", async () => {
    // Arrange
    const sut = mount();

    // Act
    await jest.advanceTimersByTimeAsync(0);
    const columns = datatable(sut).columns;

    // Assert
    const killBackoff = columns.find((column) => column.fieldName === "killBackoffUntil");
    const lastExec = columns.find((column) => column.fieldName === "lastExecutionDateTime");
    expect(killBackoff.label).toBe("Kill Backoff Until");
    expect(killBackoff.type).toBe("date");
    expect(killBackoff.typeAttributes).toEqual(lastExec.typeAttributes);
    expect(columns.indexOf(killBackoff)).toBe(columns.findIndex((column) => column.label === "Consecutive Failure") + 1);
  });

  it("givenConnected_whenIntervalElapses_thenOneApexCallPerInterval", async () => {
    // Arrange
    mount();

    // Act
    await jest.advanceTimersByTimeAsync(0);
    const callsAfterMount = getStatusByProcessor.mock.calls.length;
    await jest.advanceTimersByTimeAsync(POLL_INTERVAL_MS);

    // Assert
    expect(callsAfterMount).toBe(1);
    expect(getStatusByProcessor).toHaveBeenCalledTimes(2);
  });

  it("givenDisconnected_whenIntervalElapses_thenNoFurtherCall", async () => {
    // Arrange
    const sut = mount();
    await jest.advanceTimersByTimeAsync(0);

    // Act
    document.body.removeChild(sut);
    await jest.advanceTimersByTimeAsync(2 * POLL_INTERVAL_MS);

    // Assert
    expect(getStatusByProcessor).toHaveBeenCalledTimes(1);
  });

  it("givenDisconnectedDuringInFlightCall_whenCallResolves_thenNoTimerArmed", async () => {
    // Arrange
    let resolveCall;
    getStatusByProcessor.mockReturnValue(
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
    expect(getStatusByProcessor).toHaveBeenCalledTimes(1);
  });

  it("givenRejectedCall_whenIntervalElapses_thenErrorLoggedAndPollingResumes", async () => {
    // Arrange
    const failure = new Error("network");
    const consoleError = jest.spyOn(console, "error").mockImplementation(() => {});
    getStatusByProcessor.mockRejectedValueOnce(failure);
    mount();

    // Act
    await jest.advanceTimersByTimeAsync(0);
    await jest.advanceTimersByTimeAsync(POLL_INTERVAL_MS);

    // Assert
    expect(getStatusByProcessor).toHaveBeenCalledTimes(2);
    expect(consoleError).toHaveBeenCalledTimes(1);
    expect(consoleError).toHaveBeenCalledWith("statusByProcessorTable: refresh failed", failure);
    consoleError.mockRestore();
  });

  it("givenHostHidden_whenIntervalElapses_thenNoApexCall", async () => {
    // Arrange
    mount();
    await jest.advanceTimersByTimeAsync(0);
    clientRects.mockReturnValue([]);

    // Act
    await jest.advanceTimersByTimeAsync(POLL_INTERVAL_MS);

    // Assert
    expect(getStatusByProcessor).toHaveBeenCalledTimes(1);
  });

  it("givenHostVisibleAgain_whenIntervalElapses_thenPollingResumes", async () => {
    // Arrange
    mount();
    await jest.advanceTimersByTimeAsync(0);
    clientRects.mockReturnValue([]);
    await jest.advanceTimersByTimeAsync(POLL_INTERVAL_MS);
    clientRects.mockReturnValue([{}]);

    // Act
    await jest.advanceTimersByTimeAsync(POLL_INTERVAL_MS);

    // Assert
    expect(getStatusByProcessor).toHaveBeenCalledTimes(2);
  });
});
