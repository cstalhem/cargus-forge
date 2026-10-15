# Size test

An issue fits one session when all four are true:

1. It delivers one behaviour that you can demo or test alone.
2. One verify command proves it, and that command fails before the work.
3. After a short read of the code, the agent can name every file it changes.
4. It has no open design question for the user.

The test needs scenarios and settled questions, so it runs only after the questions are answered.

- **Pass:** all four are true.
- **Fail:** one or more is false.
- **Verdict:** give each criterion pass or fail, with one line of reason.

Where it runs:
- **discuss:** pass gives a single issue, fail gives an umbrella issue.
- **slice:** each sub-issue must pass. A sub-issue that fails is split again.
- **execute:** a failure found during the work stops execute, and the issue goes back to slice.
