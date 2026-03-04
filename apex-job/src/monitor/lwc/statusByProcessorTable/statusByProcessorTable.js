import { LightningElement } from 'lwc';
import getStatusByProcessor from '@salesforce/apex/JobMonitorController.getStatusByProcessor';
import getJobDescriptionInfos from '@salesforce/apex/JobMonitorController.getJobDescriptionInfos';

export default class StatusByProcessorTable extends LightningElement {
  rowValues = [];

  get columns() {
    return [
      { label: 'Processor', fieldName: 'processorUrl', type: 'url', typeAttributes: { label: { fieldName: 'processorName' }, target: '_blank' }, hideDefaultActions: true, wrapText: true },
      { label: 'Status', fieldName: 'status', hideDefaultActions: true },
      { label: 'Count', fieldName: 'nbRows', type: 'number', hideDefaultActions: true },
      { label: 'Nb Try', fieldName: 'nbTry', type: 'number', hideDefaultActions: true },
      { label: 'Max Chunk', fieldName: 'maxBulk', type: 'number', hideDefaultActions: true },
      { label: 'Smallest Failing', fieldName: 'smallestFailingChunk', type: 'number', hideDefaultActions: true },
      { label: 'Success Streak', fieldName: 'successStreak', type: 'number', hideDefaultActions: true },
      { label: 'Consecutive Failure', fieldName: 'consecutiveFailure', type: 'number', hideDefaultActions: true },
      { label: 'Rate Limit', fieldName: 'maxExecutionsPerMinute', type: 'number', hideDefaultActions: true },
      { label: 'Exec/min', fieldName: 'executionsInCurrentWindow', type: 'number', hideDefaultActions: true },
      { label: 'Next Exec', fieldName: 'nextExecutionDateTime', hideDefaultActions: true, wrapText: true },
      { label: 'Last Exec', fieldName: 'lastExecutionDateTime', hideDefaultActions: true, wrapText: true },
    ];
  }

  get rows() {
    return this.rowValues;
  }

  connectedCallback() {
    this.pollStatusByProcessor();
  }

  async resolveProcessorNames(ids) {
    const result = await getJobDescriptionInfos({ jobDescriptionIds: ids });
    return result.reduce((acc, r) => {
      acc[r?.Id] = {
        name: r?.ProcessorName__c,
        maxExecutionsPerMinute: r?.MaxExecutionsPerMinute__c,
        executionsInCurrentWindow: r?.ExecutionsInCurrentWindow__c
      };
      return acc;
    }, {});
  }

  async pollStatusByProcessor() {
    const rows = await getStatusByProcessor();

    if (this.arePagesDifferent(rows, this.rowValues)) {
      const names = await this.resolveProcessorNames(rows.map(row => row.processorId));
      this.rowValues = rows.map(row => {
        const info = names[row.processorId] ?? {};
        row.processorUrl = '/' + row.processorId;
        row.processorName = info.name;
        row.maxExecutionsPerMinute = info.maxExecutionsPerMinute;
        row.executionsInCurrentWindow = info.executionsInCurrentWindow;
        return row;
      });
    }

    setTimeout(() => {
      this.pollStatusByProcessor();
    }, 5000);
  }

  arePagesDifferent(newPage, currentPage) {
    return JSON.stringify(newPage) !== JSON.stringify(currentPage);
  }
}
