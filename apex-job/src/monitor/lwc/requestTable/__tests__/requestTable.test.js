import { createElement } from "lwc";
import RequestTable from "c/requestTable";
import getJobRequestPage from "@salesforce/apex/JobMonitorController.getJobRequestPage";

jest.mock("@salesforce/apex/JobMonitorController.getJobRequestPage", () => ({ default: jest.fn() }), { virtual: true });

const POLL_INTERVAL_MS = 2000;
const PAGE_SIZE = 50;

const mount = () => {
  const element = createElement("c-request-table", { is: RequestTable });
  document.body.appendChild(element);
  return element;
};

describe("c-request-table", () => {
  let clientRects;

  beforeEach(() => {
    jest.useFakeTimers();
    clientRects = jest.spyOn(Element.prototype, "getClientRects").mockReturnValue([{}]);
    getJobRequestPage.mockResolvedValue([]);
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
    clientRects.mockRestore();
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

  const aRow = (index, overrides = {}) => ({
    Id: "a00" + index,
    JobDescription__c: "a01" + index,
    JobDescription__r: { ProcessorName__c: "Processor" + index },
    IsCandidate__c: true,
    Status__c: "PENDING",
    ...overrides
  });

  const rowsOf = (element) => element.shadowRoot.querySelector("lightning-datatable").data;

  it("givenFetchedRows_whenRendered_thenRowsAreDecoratedByStatusAndCandidacy", async () => {
    // Arrange
    getJobRequestPage.mockResolvedValue([aRow(1, { Status__c: "FAILURE" }), aRow(2, { Status__c: "KILLED", IsCandidate__c: false }), aRow(3, { Status__c: "SUCCESS" }), aRow(4)]);

    // Act
    const sut = mount();
    await jest.advanceTimersByTimeAsync(0);

    // Assert
    const rows = rowsOf(sut);
    expect(rows.map((row) => row.rowStyle)).toEqual(["slds-text-color_error", "slds-theme_alert-texture slds-text-color_destructive", "slds-text-color_success", ""]);
    expect(rows[0]).toMatchObject({ RowNumber: 1, recordUrl: "/a001", ProcessorName: "Processor1", processorUrl: "/a011" });
  });

  it("givenChangedFirstPage_whenPolled_thenRowsAreReplaced", async () => {
    // Arrange
    getJobRequestPage.mockResolvedValueOnce([aRow(1)]).mockResolvedValue([aRow(2)]);
    const sut = mount();
    await jest.advanceTimersByTimeAsync(0);

    // Act
    await jest.advanceTimersByTimeAsync(POLL_INTERVAL_MS);

    // Assert
    expect(rowsOf(sut).map((row) => row.Id)).toEqual(["a002"]);
  });

  it("givenFullFirstPage_whenLoadMore_thenNextPageAppendedWithShadeAndOffset", async () => {
    // Arrange
    const fullPage = Array.from({ length: PAGE_SIZE }, (_, i) => aRow(i));
    getJobRequestPage.mockResolvedValueOnce(fullPage).mockResolvedValueOnce([aRow(50)]);
    const sut = mount();
    await jest.advanceTimersByTimeAsync(0);

    // Act
    sut.shadowRoot.querySelector("lightning-datatable").dispatchEvent(new CustomEvent("loadmore"));
    await jest.advanceTimersByTimeAsync(0);

    // Assert
    expect(getJobRequestPage).toHaveBeenLastCalledWith({ limitSize: PAGE_SIZE, offsetVal: PAGE_SIZE });
    const rows = rowsOf(sut);
    expect(rows).toHaveLength(PAGE_SIZE + 1);
    expect(rows[PAGE_SIZE]).toMatchObject({ RowNumber: PAGE_SIZE + 1, rowStyle: "slds-theme_shade" });
  });

  it("givenPartialFirstPage_whenLoadMore_thenNoFurtherFetch", async () => {
    // Arrange
    getJobRequestPage.mockResolvedValue([aRow(1)]);
    const sut = mount();
    await jest.advanceTimersByTimeAsync(0);

    // Act
    sut.shadowRoot.querySelector("lightning-datatable").dispatchEvent(new CustomEvent("loadmore"));
    await jest.advanceTimersByTimeAsync(0);

    // Assert
    expect(getJobRequestPage).toHaveBeenCalledTimes(1);
  });

  it("givenColumns_whenRendered_thenUrlColumnsOpenInNewTab", async () => {
    // Arrange
    const sut = mount();

    // Act
    const columns = sut.shadowRoot.querySelector("lightning-datatable").columns;

    // Assert
    const urlColumns = columns.filter((column) => column.type === "url");
    expect(urlColumns.map((column) => column.fieldName)).toEqual(["recordUrl", "processorUrl"]);
    expect(urlColumns.every((column) => column.typeAttributes.target === "_blank")).toBe(true);
  });

  it("givenHostHidden_whenIntervalElapses_thenNoApexCall", async () => {
    // Arrange
    mount();
    await jest.advanceTimersByTimeAsync(0);
    clientRects.mockReturnValue([]);

    // Act
    await jest.advanceTimersByTimeAsync(POLL_INTERVAL_MS);

    // Assert
    expect(getJobRequestPage).toHaveBeenCalledTimes(1);
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
    expect(getJobRequestPage).toHaveBeenCalledTimes(2);
  });
});
