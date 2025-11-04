import { LightningElement, api } from 'lwc';
import resetConsumptionModel from '@salesforce/apex/JobDescriptionActionsController.resetConsumptionModel';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class JobDescriptionResetConsumption extends LightningElement {
  @api recordId;

  @api async invoke() {
    try {
      await resetConsumptionModel({ recordId: this.recordId });
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Consumption model reset',
          message: 'The consumption model has been reset for this processor.',
          variant: 'success'
        })
      );
    } catch (e) {
      const message = e?.body?.message ?? 'Unexpected error';
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Reset failed',
          message,
          variant: 'error'
        })
      );
    } finally {
      this.dispatchEvent(new CloseActionScreenEvent());
    }
  }
}

