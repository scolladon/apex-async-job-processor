import { LightningElement, wire } from "lwc";
import { isHostVisible } from "c/hostVisibility";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import Manage_Async_Job_Engine from "@salesforce/customPermission/Manage_Async_Job_Engine";
import getEngineStatus from "@salesforce/apex/JobMonitorController.getEngineStatus";
import pauseEngine from "@salesforce/apex/JobMonitorController.pauseEngine";
import restartEngine from "@salesforce/apex/JobMonitorController.restartEngine";
import resumeEngine from "@salesforce/apex/JobMonitorController.resumeEngine";

const POLL_INTERVAL_MS = 5000;

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
    return this.recoveryBatchStatusValue ? "Scheduled" : "Not Scheduled";
  }

  get engineEnabled() {
    return this.enabled;
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
      console.error("engineControls: refresh failed", error);
    } finally {
      if (!this.stopped) {
        this.pollTimer = setTimeout(() => this.poll(), POLL_INTERVAL_MS);
      }
    }
  }

  async refresh() {
    const status = await getEngineStatus();
    this.enabled = status.enabled;
    this.executorCountValue = status.executorCount;
    this.recoveryBatchStatusValue = status.watcherScheduled;
  }

  async handleToggle() {
    if (this.enabled) {
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
      this.toast("Engine paused", "Engine is now disabled.", "success");
    } catch (e) {
      this.toast("Pause failed", this.err(e), "error");
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
      this.toast("Engine resumed", "Engine is now enabled.", "success");
    } catch (e) {
      this.toast("Resume failed", this.err(e), "error");
    } finally {
      this.loading = false;
    }
  }

  async handleRestart() {
    if (!this.canManage) return;
    this.loading = true;
    try {
      await restartEngine();
      this.toast("Restart requested", "Executor enqueued if not already running.", "success");
    } catch (e) {
      this.toast("Restart failed", this.err(e), "error");
    } finally {
      this.loading = false;
    }
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
  err(e) {
    return e?.body?.message || e?.message || "Unexpected error";
  }
}
