# secp256r1 verify

[![Open in Github][github-editor-badge]][github-editor-url] [![Github Actions][gha-quality-badge]][gha-quality-url]
[![Github Actions][gha-test-badge]][gha-test-url]
[![Github Actions][gha-static-analysis-badge]][gha-static-analysis-url]
[![Github Actions][gha-release-badge]][gha-release-url] [![Foundry][foundry-badge]][foundry]
[![License: MIT][license-badge]][license] ![Is it audited?][audit]

[github-editor-url]: https://github.dev/0x90d2b2b7fb7599eebb6e7a32980857d8/secp256r1-verify/tree/main
[github-editor-badge]: https://img.shields.io/badge/Github-Open%20the%20Editor-purple?logo=github
[gha-quality-url]:
  https://github.com/0x90d2b2b7fb7599eebb6e7a32980857d8/secp256r1-verify/actions/workflows/quality-checks.yml
[gha-quality-badge]:
  https://github.com/0x90d2b2b7fb7599eebb6e7a32980857d8/secp256r1-verify/actions/workflows/quality-checks.yml/badge.svg?branch=main
[gha-test-url]: https://github.com/0x90d2b2b7fb7599eebb6e7a32980857d8/secp256r1-verify/actions/workflows/tests.yml
[gha-test-badge]:
  https://github.com/0x90d2b2b7fb7599eebb6e7a32980857d8/secp256r1-verify/actions/workflows/tests.yml/badge.svg?branch=main
[gha-static-analysis-url]:
  https://github.com/0x90d2b2b7fb7599eebb6e7a32980857d8/secp256r1-verify/actions/workflows/static-analysis.yml
[gha-static-analysis-badge]:
  https://github.com/0x90d2b2b7fb7599eebb6e7a32980857d8/template-foundry/actions/workflows/static-analysis.yml/badge.svg?branch=main
[gha-release-url]:
  https://github.com/0x90d2b2b7fb7599eebb6e7a32980857d8/secp256r1-verify/actions/workflows/release-package.yml
[gha-release-badge]:
  https://github.com/0x90d2b2b7fb7599eebb6e7a32980857d8/secp256r1-verify/actions/workflows/release-package.yml/badge.svg
[foundry]: https://book.getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg
[license]: ./LICENSE.md
[license-badge]: https://img.shields.io/badge/License-MIT-blue.svg
[audit]: https://img.shields.io/badge/Audited-No-red.svg

## Description

`secp256r1-verify` is a specialized Solidity library that enables on-chain ECDSA signature verification on the secp256r1
curve with notable efficiency. This repository offers three distinct implementations for signature verification, each
carrying its own set of advantages and trade-offs. It sets a vital foundation for the widespread application of FIDO2's
webauthn, serving as an authentication protocol for smart-accounts.

## Installation

### Foundry

To install the `secp256r1-verify` package in a Foundry project, execute the following command:

```sh
forge install https://github.com/0x90d2b2b7fb7599eebb6e7a32980857d8/secp256r1-verify
```

This command will install the latest version of the package in your lib directory. To install a specific version of the
library, follow the instructions in the
[official Foundry documentation](https://book.getfoundry.sh/reference/forge/forge-install?highlight=forge%20install#forge-install).

### Hardhat or Truffle

To install the `secp256r1-verify` package in a Hardhat or Truffle project, use `npm` to run the following command:

```sh
npm install @0x90d2b2b7fb7599eebb6e7a32980857d8/secp256r1-verify
```

After the installation, import the package into your project and use it to generate precomputed points for the secp256r1
elliptic curve.

> ⚠️ Note: This package is not published on the npm registry, and is only available on GitHub Packages. You need to be
> authenticated with GitHub Packages to install it. For more information, please refer to the
> [troubleshooting section](#setup-github-registry). We are willing to deploy it on the npm registry if there is a need.
> Please open an issue if you would like to see this package on the npm registry.

## Usage

This repository provides three unique signature verification implementations, each having its own benefits and
drawbacks. After you've integrated this library into your project, you can freely import and use the implementation that
best suits your specific use-case and requirements. Let's take a more detailed look at each one.

> 🚨 None of the implementations have been audited. DO NOT USE THEM IN PRODUCTION.

### 1️⃣ The traditional implementation

The traditional approach is the most direct out of the three and is found in the
[ECDSA256r1 file](./src/ECDSA256r1.sol). This implementation is ready to use right out of the box; simply deploy the
library and interact with it by calling its singular exposed function, `verify`, which accepts three parameters:

- `bytes32 messageHash`: The hash of the message to verify
- `uint256[2] calldata rs`: The r and s values of the ECDSA signature
- `uint256[2] calldata point`: The public key point of the signer

This approach computes `uG + vQ` using the Strauss-Shamir's trick on the secp256r1 elliptic curve **on-chain**, where G
is the base point and Q is the public key. Though this is the least gas-efficient method, it's also the simplest to set
up. Use this approach if you're not worried about verification process costs.

### 2️⃣ The external precomputed points implementation

The external precomputed points approach is our most established solution, found in the
[ECDSA256r1Precompute file](./src/ECDSA256r1Precompute.sol). Unlike the traditional approach, this requires precomputing
a table of 256 points off-chain for each public key you wish to verify a message from.

In order to mitigate the costly on-chain computation required in the traditional approach, we precompute a table of 256
points for each public key we want to verify the message from. This table is computed off-chain and stored in a smart
contract, which is then deployed on-chain and used by the `ECDSA256r1Precompute` library to verify the message.

Instead of deploying a functional contract (a contract whose bytecode makes sense in the Ethereum Virtual Machine
context), we only deploy the precomputed table. The EVM does not require the code pushed to be understood by the virtual
machine. You can push bytecodes containing unsupported EVM opcodes. This means that the contract storing the precomputed
table isn't a traditional contract; it's an immutable piece of on-chain data. Calling it will result in a revert as the
instructions set into it don't make sense.

We deploy the precomputed table this way because it allows us to use the highly gas-efficient
[`extcodecopy`](https://www.evm.codes/#3c) opcode to read the table. This opcode is used to copy some segments of a
contract's bytecode into memory. In our case, the contract's bytecode is the precomputed table, so we can read the table
in a very gas-efficient way (compared to storing it in storage -- which would be costly in gas terms because it would
necessitate using multiple expensive [SLOAD](https://www.evm.codes/#54) opcodes).

The `verify` function of this implementation takes 3 parameters:

- `bytes32 messageHash`: The hash of the message to verify
- `uint256[2] calldata rs`: The r and s values of the ECDSA signature
- `address precomputedTable`: The address of the contract containing the precomputations

This method significantly outperforms the traditional approach in gas terms, but it's also more challenging to implement
as it requires off-chain point precomputations and on-chain storage before message verification. Furthermore, deployment
gas costs must be factored in. It is recommended to use this approach if you are concerned about the cost of the
verification process and your scenario involves multiple verifications from the same public key.

> 🔜 Example scripts will soon be available to assist with off-chain point precomputations and on-chain precomputed
> table deployment. Meanwhile, if you want to precompute the points off-chain yourself, you can use the following
> [library](https://github.com/0x90d2b2b7fb7599eebb6e7a32980857d8/secp256r1-computation) developed by us for this
> purpose.

### 3️⃣ The internal precomputed points implementation (**work in progress**)

The internal precomputed points approach is our latest solution, still a work-in-progress and located in the
[ECDSA256r1PrecomputeInternal file](./src/ECDSA256PrecomputeInternal.sol). Like the external precomputed points
approach, you'll need to precompute a table of 256 points off-chain for each public key from which you wish to verify a
message. The difference here is that the precomputed table is stored directly within the contract that uses the library,
rather than being stored in a dedicated account. Let's examine how this works.

Like the external precomputed points approach, this implementation sidesteps the expensive on-chain computation of the
traditional approach. The process for generating precomputed points remains the same until we reach the point of
on-chain precomputed table deployment. Instead of deploying the precomputed table on-chain, we store it directly within
the contract that utilizes the library. One way to achieve this is to create a contract containing a constant of the
same size as the precomputed tables (64\*256 bytes are crucial), compile it once, and then whenever you need it replace
the placeholder value of the constant with the precomputed points in the compiled contract's bytecode. In addition to
replacing the placeholder value of the constant with the precomputed points, the script must calculate the constant's
offset in the contract's bytecode. This offset is used to locate this constant in the contract's bytecode.

Once this is accomplished and the contract is deployed on-chain, the same contract (functional this time because the
precomputed points coexist with the contract's logic) can read the precomputed table from its own bytecode using the
[codecopy](https://www.evm.codes/#39) opcode. This opcode copies segments of the bytecode in the current environment
into memory. In our case, the contract's bytecode contains the precomputed table, allowing us to read the precomputed
table in a highly gas-efficient manner using the constant's offset in the contract's bytecode (calculated by the
script).

The `verify` function of this implementation takes 3 parameters:

- `bytes32 message`: The hash of the message to verify
- `uint256[2] calldata rs`: The r and s values of the ECDSA signature
- `uint256 precomputedOffset`: The offset where the precomputed points starts in the bytecode

The `codecopy` opcode is cheaper than `extcodecopy` because it doesn't need to perform a call to another contract; the
account's code is already hot. `codecopy` is used in a way that only loads part of the precomputation into memory, as
opposed to copying the entire table into memory before manipulation.

However, this approach does come with significant trade-offs. While it could reduce gas consumption in a unique-signer
scenario that can't be altered, it's not recommended for scenarios where the public key allowed for a contract may
change. In addition, each contract includes its own precomputed points, in contrast to a scenario where precomputed
points for a specific public key are stored once in a dedicated account and used by multiple contracts. This approach is
definitely less composable and flexible than the external precomputed points approach. These factors should be weighed
before considering this approach.

> 🚨 As stated, this implementation is highly experimental. At this point, this implementation hasn't been tested. IT IS
> NOT RECOMMENDED FOR USE IN PRODUCTION.

> 🔜 Example scripts will soon be available to assist with off-chain point precomputations and on-chain precomputed
> table deployment. Meanwhile, if you want to precompute the points off-chain yourself, you can use the following
> [library](https://github.com/0x90d2b2b7fb7599eebb6e7a32980857d8/secp256r1-computation) developed by us for this
> purpose.

### Scripts

This repository includes a [script](./script) directory containing a set of scripts that can be used to deploy the
different implementations on-chain. Each script contains a set of instructions and an example of how to use it. The
scripts are expected to be run using the `forge script` command.

## Gas reports

These gas reports were produced using the `0.8.19` version of the Solidity compiler, specifically for the
[`0.3.0`](https://github.com/0x90d2b2b7fb7599eebb6e7a32980857d8/secp256r1-verify/releases/tag/v0.3.0) version of the
library. The library version corresponds to commit
[5436b12](https://github.com/0x90d2b2b7fb7599eebb6e7a32980857d8/secp256r1-verify/commit/5436b12f40e3cb5d0f593709067b22054e4164b8).

### The traditional implementation [🔗](#1️⃣-the-traditional-implementation)

|                 |                 |        |        |        |
| --------------- | --------------- | ------ | ------ | ------ |
| Deployment Cost | Deployment Size |        |        |        |
| 978643          | 4946            |        |        |        |
| Function Name   | min             | avg    | median | max    |
| verify          | 448             | 110273 | 197391 | 212108 |

### The external precomputed points implementation [🔗](#2️⃣-the-external-precomputed-points-implementation-recommended)

|                 |                 |       |        |       |
| --------------- | --------------- | ----- | ------ | ----- |
| Deployment Cost | Deployment Size |       |        |       |
| 649708          | 3303            |       |        |       |
| Function Name   | min             | avg   | median | max   |
| verify          | 472             | 44794 | 59185  | 75396 |

Although the prerequisites for implementing this approach are more complex, the gas cost for the verification process is
over three times less expensive than the traditional method.

> ℹ️ It's important to note that since 2021, there has been ongoing discussion about a potential yet unplanned overhaul
> of the extcodecopy opcode. If such a revamp occurs, it could result in a significant increase in the gas cost of this
> implementation. This is an issue worth monitoring. You can learn more about the possible revamp in this
> [blog post](https://notes.ethereum.org/@vbuterin/witness_gas_cost_2).

### The external precomputed points implementation [🔗](#3️⃣-the-internal-precomputed-points-implementation-work-in-progress)

As this implementation is still work-in-progress, the benchmark is not yet available.

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
  [here](https://github.com/0x90d2b2b7fb7599eebb6e7a32980857d8/secp256r1-computation).

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

## Troubleshootings

### Setup Github registry

You need to configure npm to use the Github registry. You can do so using the following command in your terminal:

```sh
npm config set @0x90d2b2b7fb7599eebb6e7a32980857d8:registry=https://npm.pkg.github.com
```

This will instruct npm to use the Github registry for packages deployed by `@0x90d2b2b7fb7599eebb6e7a32980857d8`.

Once the Github registry is configured, you have to create a **classic** token on Github. To do so, go to your
[Github settings](https://github.com/settings/tokens). The token must have the read:packages scope. Once you have
created the token, use the following command in your terminal to authenticate to the Github registry:

```sh
npm login --auth-type=legacy --registry=https://npm.pkg.github.com
```

Your Github username is the username, and the password is the token you just created. At this point, your git should be
configured to use the Github Package Registry for our packages.

> ⚠️ For more information, please refer to the
> [GitHub documentation](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-npm-registry#installing-a-package)

## Acknowledgements

Special thanks to [rdubois-crypto](https://github.com/rdubois-crypto) for developing the reference implementation
[here](https://github.com/rdubois-crypto/FreshCryptoLib) and for the invaluable cryptographic guidance. The
implementation, and more precisely, all the ingenious mathematical tricks you can discover in this repository, are from
his mind. My role here was to clean up his work to improve the chances of accepting contributions. All credit goes to
him.

If you want to learn more about the math behind this project, check out
[this publication](https://eprint.iacr.org/2023/939.pdf) written by
[rdubois-crypto](https://twitter.com/RenaudDUBOIS10).
