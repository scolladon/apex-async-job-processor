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
      acc[r?.Id] = r?.ProcessorName__c;
      return acc;
    }, {});
  }

  async pollStatusByProcessor() {
    const rows = await getStatusByProcessor();

    if (this.arePagesDifferent(rows, this.rowValues)) {
      const names = await this.resolveProcessorNames(rows.map(row => row.processorId));
      this.rowValues = rows.map(row => {
        row.processorUrl = '/' + row.processorId;
        row.processorName = names[row.processorId];
        return row;
      });
    }

    setTimeout(() => {
      this.pollStatusByProcessor();
    }, 5000);
  }

  arePagesDifferent(newPage, currentPage) {
    if (newPage.length !== currentPage.length) {
      return true;
    }
    for (let i = 0; i < newPage.length; i++) {
      if (newPage[i].Id !== currentPage[i].Id) {
        return true;
      }
    }
    return false;
  }
}
