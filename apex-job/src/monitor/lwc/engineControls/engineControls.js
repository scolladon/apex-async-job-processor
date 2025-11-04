import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import Manage_Async_Job_Engine from "@salesforce/customPermission/Manage_Async_Job_Engine";
import isEnabled from '@salesforce/apex/JobMonitorController.isEnabled';
import getExecutorCount from '@salesforce/apex/JobMonitorController.getExecutorCount';
import isRecoveryBatchAlive from '@salesforce/apex/JobMonitorController.isRecoveryBatchAlive';
import pauseEngine from '@salesforce/apex/JobMonitorController.pauseEngine';
import restartEngine from '@salesforce/apex/JobMonitorController.restartEngine';
import resumeEngine from '@salesforce/apex/JobMonitorController.resumeEngine';

export default class EngineControls extends LightningElement {
  enabled = false;
  canManage = Manage_Async_Job_Engine === true;
  loading = false;
  executorCountValue = 0;
  recoveryBatchStatusValue = false;

  get executorCount() {
    return this.executorCountValue;
  }

  get recoveryBatchStatus() {
    return this.recoveryBatchStatusValue ? 'Scheduled' : 'Not Scheduled';
  }

  get engineEnabled() {
    return this.enabled;
  }

  connectedCallback() {
    setInterval(() => {
      this.pollExecutorCount();
      this.pollRecoveryBatchStatus();
      this.pollEnabled();
    }, 500);
  }

  async pollEnabled() {
    this.enabled = await isEnabled();
  }

  async pollExecutorCount() {
    this.executorCountValue = await getExecutorCount();
  }

  async pollRecoveryBatchStatus() {
    this.recoveryBatchStatusValue = await isRecoveryBatchAlive();
  }

  async handleToggle() {
    if(this.enabled) {
      await this.handlePause();
    } else {
      await this.handleResume();
    }
  }

  async handlePause() {
    if (!this.canManage) return;
    this.loading = true;
    try {
      const ok = await pauseEngine();
      this.enabled = !ok ? this.enabled : false;
      this.toast('Engine paused', 'Engine is now disabled.', 'success');
    } catch (e) {
      this.toast('Pause failed', this.err(e), 'error');
    } finally {
      this.loading = false;
    }
  }

  async handleResume() {
    if (!this.canManage) return;
    this.loading = true;
    try {
      const ok = await resumeEngine();
      this.enabled = ok ? true : this.enabled;
      this.toast('Engine resumed', 'Engine is now enabled.', 'success');
    } catch (e) {
      this.toast('Resume failed', this.err(e), 'error');
    } finally {
      this.loading = false;
    }
  }

  async handleRestart() {
    if (!this.canManage) return;
    this.loading = true;
    try {
      await restartEngine();
      this.toast('Restart requested', 'Executor enqueued if not already running.', 'success');
    } catch (e) {
      this.toast('Restart failed', this.err(e), 'error');
    } finally {
      this.loading = false;
    }
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
  err(e) {
    return e?.body?.message || e?.message || 'Unexpected error';
  }
}
