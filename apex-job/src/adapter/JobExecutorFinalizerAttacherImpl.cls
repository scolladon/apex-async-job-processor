public without sharing class JobExecutorFinalizerAttacherImpl implements JobExecutorFinalizerAttacher {
  public void attach(Finalizer finalizer) {
    System.attachFinalizer(finalizer);
  }
}
