import assert = require("assert");

async function tryCatch(promise: any, message: any) {
  try {
    await promise;
    throw null;
  } catch (error) {
    assert(error, "Expected an error but did not get one");
  }
}

module.exports = {
  catchRevert: async function (promise: any) {
    await tryCatch(promise, "revert");
  },
};
