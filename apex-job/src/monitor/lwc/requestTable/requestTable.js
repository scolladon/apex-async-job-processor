import { LightningElement } from 'lwc';
import getJobRequestPage from '@salesforce/apex/JobMonitorController.getJobRequestPage';

export default class RequestTable extends LightningElement {
  rowValues = [];
  isLoading = false;
  pageSize = 50;
  offset = 0;
  hasMore = true;

  get columns() {
    return [
      { label: '#', fieldName: 'RowNumber', cellAttributes: { class: { fieldName: 'rowStyle' } }, hideDefaultActions: true },
      { label: 'Name', fieldName: 'recordUrl', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' }, cellAttributes: { class: { fieldName: 'rowStyle' } }, hideDefaultActions: true, wrapText: true },
      { label: 'Processor', fieldName: 'processorUrl', type: 'url', typeAttributes: { label: { fieldName: 'ProcessorName' }, target: '_blank' },cellAttributes: { class: { fieldName: 'rowStyle' } }, hideDefaultActions: true, wrapText: true },
      { label: 'Status', fieldName: 'Status__c', cellAttributes: { class: { fieldName: 'rowStyle' } }, hideDefaultActions: true },
      { label: 'Enabled', fieldName: 'Enabled__c', type: 'boolean', cellAttributes: { class: { fieldName: 'rowStyle' } }, hideDefaultActions: true },
      { label: 'Is Candidat?', fieldName: 'IsCandidat__c', type: 'boolean', cellAttributes: { class: { fieldName: 'rowStyle' } }, hideDefaultActions: true },
      { label: '#Attempt', fieldName: 'AttemptNumber__c', type: 'number', cellAttributes: { class: { fieldName: 'rowStyle' } }, hideDefaultActions: true },
      { label: 'Wait Time (ms)', fieldName: 'WaitTime__c', type: 'number', cellAttributes: { class: { fieldName: 'rowStyle' } }, hideDefaultActions: true },
      { label: 'Chunk Run Time (ms)', fieldName: 'ChunkRunTime__c', type: 'number', cellAttributes: { class: { fieldName: 'rowStyle' } }, hideDefaultActions: true },
      { label: 'Unit Run Time (ms)', fieldName: 'UnitRunTime__c', type: 'number', cellAttributes: { class: { fieldName: 'rowStyle' } }, hideDefaultActions: true },
      { label: 'Processing Time (ms)', fieldName: 'ProcessingTime__c', type: 'number', cellAttributes: { class: { fieldName: 'rowStyle' } }, hideDefaultActions: true },
      { label: 'Last Selection', fieldName: 'LastSelectionDateTime__c', cellAttributes: { class: { fieldName: 'rowStyle' } }, hideDefaultActions: true },
      { label: 'Last Exec', fieldName: 'LastExecutionDateTime__c', cellAttributes: { class: { fieldName: 'rowStyle' } }, hideDefaultActions: true, wrapText: true },
      { label: 'Next Exec', fieldName: 'NextExecutionDateTime__c', cellAttributes: { class: { fieldName: 'rowStyle' } }, hideDefaultActions: true, wrapText: true },
      { label: 'Last Message', fieldName: 'LastExecutionMessage__c', cellAttributes: { class: { fieldName: 'rowStyle' } }, hideDefaultActions: true },
      { label: 'Argument', fieldName: 'Argument__c', cellAttributes: { class: { fieldName: 'rowStyle' } }, hideDefaultActions: true },
    ];
  }

  get rows() {
    return this.rowValues;
  }

  connectedCallback() {
    this.refreshData();
  }

  async refreshData() {
    const data = await getJobRequestPage({ limitSize: this.pageSize, offsetVal: 0 });
    const currentFirstPage = this.rowValues.slice(0, this.pageSize);
    if (this.arePagesDifferent(data, currentFirstPage)) {
      this.isLoading = true;
      this.rowValues = await this.transformRows(data, 0);
      this.offset = this.rowValues.length;
      this.hasMore = this.rowValues.length === this.pageSize;
      this.isLoading = false;
    }
    setTimeout(() => {
      this.refreshData();
    }, 2000);
  }

  async handleLoadMore() {
    if (this.isLoading || !this.hasMore) {
      return;
    }
    this.isLoading = true;
    const offsetForFetch = this.rowValues.length;
    const data = await getJobRequestPage({ limitSize: this.pageSize, offsetVal: offsetForFetch });
    const transformed = await this.transformRows(data, offsetForFetch);
    this.rowValues = [...this.rowValues, ...transformed];
    this.offset = offsetForFetch + data.length;
    this.hasMore = data.length === this.pageSize;
    this.isLoading = false;
  }

  async transformRows(data, offset) {
    return data.map((row, i) => {
      const classes = [];
      const absoluteIndex = i + offset;
      if (absoluteIndex > this.pageSize - 1) {
        classes.push('slds-theme_shade');
      }
      if (!row.IsCandidat__c) {
        classes.push('slds-theme_alert-texture');
      }
      switch (row.Status__c) {
        case 'FAILURE':
          classes.push('slds-text-color_error');
          break;
        case 'KILLED':
          classes.push('slds-text-color_destructive');
          break;
        case 'SUCCESS':
          classes.push('slds-text-color_success');
          break;
      }
      return {
        ...row,
        RowNumber: absoluteIndex + 1,
        recordUrl: '/' + row.Id,
        ProcessorName: row.JobDescription__r.ProcessorName__c,
        processorUrl: '/' + row.JobDescription__c,
        rowStyle: classes.join(' ')
      };
    });
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
