> ❌ This repository is deprecated. Please refer to the [crypto-lib](https://github.com/get-smooth/CryptoLib) repository
> to find the latest implementation of the secp256r1 curve.

# secp256r1 verify

[![Open in Github][github-editor-badge]][github-editor-url] [![Github Actions][gha-quality-badge]][gha-quality-url]
[![Github Actions][gha-test-badge]][gha-test-url]
[![Github Actions][gha-static-analysis-badge]][gha-static-analysis-url]
[![Github Actions][gha-release-badge]][gha-release-url] [![Foundry][foundry-badge]][foundry]
[![License: MIT][license-badge]][license] ![Is it audited?][audit]

[github-editor-url]: https://github.dev/get-smooth/secp256r1-verify/tree/main
[github-editor-badge]: https://img.shields.io/badge/Github-Open%20the%20Editor-purple?logo=github
[gha-quality-url]: https://github.com/get-smooth/secp256r1-verify/actions/workflows/quality-checks.yml
[gha-quality-badge]:
  https://github.com/get-smooth/secp256r1-verify/actions/workflows/quality-checks.yml/badge.svg?branch=main
[gha-test-url]: https://github.com/get-smooth/secp256r1-verify/actions/workflows/tests.yml
[gha-test-badge]: https://github.com/get-smooth/secp256r1-verify/actions/workflows/tests.yml/badge.svg?branch=main
[gha-static-analysis-url]: https://github.com/get-smooth/secp256r1-verify/actions/workflows/static-analysis.yml
[gha-static-analysis-badge]:
  https://github.com/get-smooth/template-foundry/actions/workflows/static-analysis.yml/badge.svg?branch=main
[gha-release-url]: https://github.com/get-smooth/secp256r1-verify/actions/workflows/release-package.yml
[gha-release-badge]: https://github.com/get-smooth/secp256r1-verify/actions/workflows/release-package.yml/badge.svg
[foundry]: https://book.getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg
[license]: ./LICENSE.md
[license-badge]: https://img.shields.io/badge/License-MIT-blue.svg
[audit]: https://img.shields.io/badge/Audited-No-red.svg

## Description

`secp256r1-verify` is a specialized Solidity library that enables on-chain ECDSA signature verification on the secp256r1
curve with notable efficiency. This repository is a simple implementation for signature verification. It sets a vital
foundation for the widespread application of FIDO2's Webauthn, serving as an authentication protocol for smart accounts.
If you are looking for an alternative implementation, such as the ones based on the `*codedopy` opcodes, check out
Renaud Dubois' [FreshCryptoLib](https://github.com/rdubois-crypto/FreshCryptoLib) repository.

## Installation

### Foundry

To install the `secp256r1-verify` package in a Foundry project, execute the following command:

```sh
forge install https://github.com/get-smooth/secp256r1-verify
```

This command will install the latest version of the package in your lib directory. To install a specific version of the
library, follow the instructions in the
[official Foundry documentation](https://book.getfoundry.sh/reference/forge/forge-install?highlight=forge%20install#forge-install).

### Hardhat or Truffle

To install the `secp256r1-verify` package in a Hardhat or Truffle project, use `npm` to run the following command:

```sh
npm install @smoo.th/secp256r1-verify
```

After the installation, import the package into your project and use it.

## Usage

This repository provides a unique verification implementation. After you've integrated this library into your project,
you can freely import the `ECDSA256r1` and use it.

> 🚨 The implementations have not been audited. DO NOT USE IT IN PRODUCTION.

### 1️⃣ The traditional implementation

The traditional approach is the implementation present in this repository. You can take a look to it here:
[ECDSA256r1 file](./src/ECDSA256r1.sol). This implementation is ready to use right out of the box; simply deploy the
library and interact with it by calling its singular exposed function, `verify`, which accepts three parameters:

- `bytes32 messageHash`: The hash of the message to verify
- `uint256[2] calldata rs`: The r and s values of the ECDSA signature
- `uint256[2] calldata point`: The public key point of the signer

This approach computes `uG + vQ` using the Strauss-Shamir's trick on the secp256r1 elliptic curve **on-chain**, where G
is the base point and Q is the public key.

### Scripts

This repository includes a [script](./script) directory containing a set of scripts that can be used to deploy the
different implementations on-chain. Each script contains a set of instructions and an example of how to use it. The
scripts are expected to be run using the `forge script` command.

## Gas reports

These gas reports were produced using the `0.8.19` version of the Solidity compiler (with 100k optimizer runs),
specifically for the [`0.4.1`](https://github.com/get-smooth/secp256r1-verify/releases/tag/v0.4.1) version of the
library. The library version corresponds to commit
[4d0716f](https://github.com/get-smooth/secp256r1-verify/commit/4d0716fc6fd14a92488442e1dd0c18bb2c24ff41).

> ℹ️ If you import the library into your project, we strongly recommend you to enable the optimizer with 100k in order
> to have the best gas consumption.

### The traditional implementation [🔗](#1️⃣-the-traditional-implementation)

| Deployment Cost | Deployment Size |        |        |        |
| --------------- | --------------- | ------ | ------ | ------ |
| 1002641         | 5040            |        |        |        |
| Function Name   | min             | avg    | median | max    |
| verify          | 192620          | 202959 | 202905 | 210079 |

## Contributing

To contribute to the project, you must have Foundry and Node.js installed on your system. You can download them from
their official websites:

- Node.js: https://nodejs.org/
- Foundry: https://book.getfoundry.sh/getting-started/installation

> ℹ️ We recommend using [nvm](https://github.com/nvm-sh/nvm) to manage your Node.js versions. Nvm is a flexible node
> version manager that allows you to switch between different versions of Node.js effortlessly. This repository includes
> a `.nvmrc` file at the root of the project. If you have nvm installed, you can run `nvm use` at the root of the
> project to automatically switch to the appropriate version of Node.js.

Following the installation of Foundry and Node.js, there's an additional dependency called `make` that needs to be
addressed.

`make` is a build automation tool that employs a file known as a makefile to automate the construction of executable
programs and libraries. The makefile details the process of deriving the target program from the source files and other
dependencies. This allows developers to automate repetitive tasks and manage complex build processes efficiently. `make`
is our primary tool in a multi-environment repository. It enables us to centralize all commands into a single file
([the makefile](./makefile)), eliminating the need to deal with `npm` scripts defined in a package.json or remembering
the various commands provided by the `foundry` cli. If you're unfamiliar with `make`, you can read more about it
[here](https://www.gnu.org/software/make/manual/make.html).

`make` is automatically included in all modern Linux distributions. If you're using Linux, you should be able to use
`make` without any additional steps. If not, you can likely find it in the package tool you usually use. MacOS users can
install `make` using [Homebrew](https://formulae.brew.sh/formula/make) with the following command:

```sh
brew install make
```

At this point, you should have all the required dependencies installed on your system.

> 💡 Running make at the root of the project will display a list of all the available commands. This can be useful to
> know what you can do

### Installing the dependencies

To install the project dependencies, you can run the following command:

```sh
make install
```

This command will install the forge dependencies in the `lib/` directory, the npm dependencies in the `node_modules`
directory and the git hooks defined in the project ([refer to the Git hooks section](#git-hooks)s to learn more about
them). These dependencies aren't shipped in production; they're utility dependencies used to build, test, lint, format,
and more, for the project.

> ⚠️ This package uses a dependency installed on the Github package registry, meaning you need to authenticate with
> GitHub Packages to install it. For more information, refer to the [troubleshooting section](#setup-github-registry).
> We're open to deploying it on the npm registry if there's a demand for it. Please open an issue if you'd like to see
> this package on the npm registry.

Next, let's set up the git hooks.

### Git hooks

This project uses `Lefthook` to manage Git hooks, which are scripts that run automatically when certain Git events
occur, such as committing code or pushing changes to a remote repository. `Lefthook` simplifies the management and
execution of these scripts.

After installing the dependencies, you can configure the Git hooks by running the following command in the project
directory:

```sh
make hooks-i
```

This command installs a Git hook that runs Lefthook before pushing code to a remote repository. If Lefthook fails, the
push is aborted.

If you wish to run Lefthook manually, you can use the following command:

```sh
make hooks
```

This will run all the Git hooks defined in the [lefthook](./lefthook.yml) file.

#### Skipping git hooks

Should you need to intentionally skip Lefthook, you can pass the `--no-verify` flag to the git push command. To bypass
Lefthook when pushing code, use the following command:

```sh
git push origin --no-verify
```

## Testing

### Unit tests

The unit tests are stored in the `test` directory. They test individual functions of the package in isolation. These
tests are automatically run by GitHub Actions with every push to the `main` branch and on every pull request targeting
this branch. They are also automatically run by the git hook on every push to a remote repository if you have installed
it ([refer to the Git hooks section](#git-hooks)). Alternatively, you can run them locally by executing the following
command in the project directory:

```sh
make test
```

> ℹ️ By adding the sufix `-v` the test command will run in verbose mode, displaying valuable output for debugging.

For your information, these tests are written using [forge](https://book.getfoundry.sh/forge/tests), and some employ the
property-based testing pattern _(fuzzing)_ to generate random inputs for the functions under test.

Additionally, some test fixtures have been generated using [Google's wycheproof](https://github.com/google/wycheproof)
project, which tests crypto libraries against known attacks. These fixtures are located in the
[fixtures](./test/fixtures) directory.

The tests use two different `cheatcodes` you should be aware of:

- `vm.readFile`: This cheatcode lets us read the fixtures data from the test/fixtures directory. This means that every
  time you run the test suite, the fixtures are read from the disk, eliminating the need to copy/paste the fixtures into
  the test files. However, if you modify a fixture, you need to rerun the tests to see the changes. More information is
  available [here](https://book.getfoundry.sh/cheatcodes/fs?highlight=readFile).
- `vm.ffi`: This cheatcode allows us to execute an arbitrary command during the test suite. This cheatcode is not
  enabled by default when creating a new foundry project, but in our case, it's enabled in our configuration
  ([foundry configuration](./foundry.toml)) for all tests. This cheatcode is used to run the computation library that
  calculates 256 points on the secp256r1 elliptic curve from a public key. This is required for the variants that need
  these points to be deployed on-chain. Therefore, even if it's not explicit, every time you run the test suite, a
  Node.js script is executed multiple times. You can learn more about the library we use
  [here](https://github.com/get-smooth/secp256r1-computation).

> 📖 Cheatcodes are special instructions exposed by Foundry to enhance the developer experience. Learn more about them
> [here](https://book.getfoundry.sh/cheatcodes/).

> 💡 Run `make` to learn how to run the test in verbose mode, or to display the coverage or the gas consumption.

### Quality

This repository uses `forge-fmt`, `solhint` and `prettier` to enforce code quality. These tools are automatically run by
the GitHub Actions on every push to the `main` branch and on every pull request targeting this branch. They are also
automatically run by the git hook on every push to a remote repository if you have installed it
([refer to the Git hooks section](#git-hooks)). Alternatively, you can run them locally by executing the following
command in the project directory:

```sh
make lint # run the linter
make format # run the formatter
make quality # run both
```

> ℹ️ By adding the sufix `-fix` the linter and the formatter will try to fix the issues automatically.

## Acknowledgements

Special thanks to [rdubois-crypto](https://github.com/rdubois-crypto) for developing the reference implementation
[here](https://github.com/rdubois-crypto/FreshCryptoLib) and for the invaluable cryptographic guidance. The
implementation, and more precisely, all the ingenious mathematical tricks you can discover in this repository, are from
his mind. My role here was to clean up his work to improve the chances of accepting contributions. All credit goes to
him.

If you want to learn more about the math behind this project, check out
[this publication](https://eprint.iacr.org/2023/939.pdf) written by
[rdubois-crypto](https://twitter.com/RenaudDUBOIS10).
