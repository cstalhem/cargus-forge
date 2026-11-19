# Scenario tests

A scenario test is the test that proves one scenario. It has three properties:
- It fails when the code the scenario rests on is broken.
- It takes its expected value from the scenario's THEN.
- It asserts a result rather than a call.

## No-test reasons
A scenario has no scenario test only for exactly four reasons:
1. The result is wording in a doc or a prompt that a test could only match as text.
2. A compiler, type checker or linter already fails on it.
3. An existing test already fails without the change.
4. Only a real run can show it.

## Good red
A good red is the test's own assertion failing, or the thing the scenario adds being absent. A syntax error, a missing test file or a broken setup is not one.

## Fake-green moves
These make a test pass without proving the code:
- a mock of the thing under test;
- a fixed sleep;
- a retry;
- a raised timeout;
- a skipped test;
- an existing test removed or loosened with no scenario that changes its behaviour.
