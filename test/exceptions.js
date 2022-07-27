async function tryCatch(promise, message) {
  try {
    await promise;
    throw null;
  } catch (error) {
    assert(error, "Expected an error but did not get one");
  }
}

module.exports = {
  catchRevert: async function (promise) {
    await tryCatch(promise, "revert");
  },
};
