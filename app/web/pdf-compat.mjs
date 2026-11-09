// Syncfusion 34 calls PDFDocumentProxy.destroy(), removed in PDF.js 6.
// Keep the current PDF.js engine and release its documented loading task.
export function viewerPdfApi(pdfjs) {
  return {
    ...pdfjs,
    getDocument(...args) {
      const task = pdfjs.getDocument(...args);
      const ready = task.promise.then(document => {
        if (typeof document.destroy !== 'function') document.destroy = () => task.destroy();
        return document;
      });
      Object.defineProperty(task, 'promise', {value: ready});
      return task;
    },
  };
}
