import { LightningElement } from "lwc";
import { isHostVisible } from "c/hostVisibility";
import getStatusByProcessor from "@salesforce/apex/JobMonitorController.getStatusByProcessor";
import getJobDescriptionInfos from "@salesforce/apex/JobMonitorController.getJobDescriptionInfos";

const POLL_INTERVAL_MS = 5000;

export default class StatusByProcessorTable extends LightningElement {
  rowValues = [];

  get columns() {
    return [
      { label: "Processor", fieldName: "processorUrl", type: "url", typeAttributes: { label: { fieldName: "processorName" }, target: "_blank" }, hideDefaultActions: true, wrapText: true },
      { label: "Status", fieldName: "status", hideDefaultActions: true },
      { label: "Count", fieldName: "nbRows", type: "number", hideDefaultActions: true },
      { label: "Max Chunk", fieldName: "maxBulk", type: "number", hideDefaultActions: true },
      { label: "Smallest Failing", fieldName: "smallestFailingChunk", type: "number", hideDefaultActions: true },
      { label: "Success Streak", fieldName: "successStreak", type: "number", hideDefaultActions: true },
      { label: "Consecutive Failure", fieldName: "consecutiveFailure", type: "number", hideDefaultActions: true },
      { label: "Rate Limit", fieldName: "maxExecutionsPerMinute", type: "number", hideDefaultActions: true },
      { label: "Exec/min", fieldName: "executionsInCurrentWindow", type: "number", hideDefaultActions: true },
      {
        label: "Last Exec",
        fieldName: "lastExecutionDateTime",
        type: "date",
        typeAttributes: { year: "numeric", month: "short", day: "2-digit", hour: "2-digit", minute: "2-digit", second: "2-digit" },
        hideDefaultActions: true,
        wrapText: true
      }
    ];
  }

  get rows() {
    return this.rowValues;
  }

  connectedCallback() {
    this.stopped = false;
    this.poll();
  }

  disconnectedCallback() {
    this.stopped = true;
    clearTimeout(this.pollTimer);
  }

  async poll() {
    try {
      if (isHostVisible(this.template.host)) {
        await this.refresh();
      }
    } catch (error) {
      console.error("statusByProcessorTable: refresh failed", error);
    } finally {
      if (!this.stopped) {
        this.pollTimer = setTimeout(() => this.poll(), POLL_INTERVAL_MS);
      }
    }
  }

  async refresh() {
    const groups = await getStatusByProcessor();
    const infos = await getJobDescriptionInfos({ jobDescriptionIds: groups.map((group) => group.processorId) });
    const infoById = new Map(infos.map((info) => [info.Id, info]));
    this.rowValues = groups.map((group) => this.mergeRow(group, infoById.get(group.processorId) ?? {}));
  }

  mergeRow(group, info) {
    return {
      ...group,
      processorUrl: "/" + group.processorId,
      processorName: info.ProcessorName__c,
      maxBulk: info.MaxChunkSize__c,
      smallestFailingChunk: info.SmallestFailingChunk__c,
      successStreak: info.SuccessStreak__c,
      consecutiveFailure: info.ConsecutiveFailures__c,
      lastExecutionDateTime: info.LastExecutionDateTime__c,
      maxExecutionsPerMinute: info.MaxExecutionsPerMinute__c,
      executionsInCurrentWindow: info.ExecutionsInCurrentWindow__c
    };
  }
}
