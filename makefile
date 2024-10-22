.SILENT:

## define the shell function that is used to run commands defined in this file
define shell-functions
: BEGIN
runcmd() {
	_cmd=$@;

	script_cmd="script -q /dev/null ${_cmd[@]} >&1";
	script -q /dev/null -c echo 2> /dev/null > /dev/null && script_cmd="script -q /dev/null -c \"${_cmd[@]}\" >&1";

	printf "\e[90;1m[\e[90;1mmake: \e[0;90;1mcmd\e[0;90;1m]\e[0m \e[0;93;1m➔ \e[97;1m$_cmd\e[0m\n" \
		&& ( \
			cmd_output=$(eval "$script_cmd" | tee /dev/tty; exit ${PIPESTATUS[0]}); cmd_exit_code=$?; \
			[ -z "$cmd_output" ] || ([ -z "$(tr -d '[:space:]' <<< $cmd_output)" ] && printf "\e[1A"); \
			[[ "$cmd_exit_code" -eq 0 ]] || return $cmd_exit_code \
		) || (_test_exit=$? && return $_test_exit) && [ $? -eq 0 ] || return $?
}
: END
endef

# write the shell function in a git ignored file named .make.functions.sh
$(shell sed -n '/^: BEGIN/,/^: END/p' $(lastword $(MAKEFILE_LIST)) > .make.functions.sh)
SHELL := /bin/bash --init-file .make.functions.sh -i

# print when running `make` without arguments
default:
	printf """\e[37musage:\e[0m\n \
		  \e[90m$$ \e[0;97;1mmake \e[0;92;1minstall               \e[0;90m➔ \e[32;3minstall the git submodules and the npm dependencies \e[0m\n \
		  \e[90m$$ \e[0;97;1mmake \e[0;92;1mcompile               \e[0;90m➔ \e[32;3mcompile the contracts \e[0m\n \
		  \e[90m$$ \e[0;97;1mmake \e[0;92;1mcompile-s             \e[0;90m➔ \e[32;3mcompile the contracts and print their size \e[0m\n \
		  \e[90m$$ \e[0;97;1mmake \e[0;92;1mtest                  \e[0;90m➔ \e[32;3mrun the tests \e[0m\n \
		  \e[90m$$ \e[0;97;1mmake \e[0;92;1mtest-v                \e[0;90m➔ \e[32;3mrun the tests in verbose mode \e[0m\n \
		  \e[90m$$ \e[0;97;1mmake \e[0;92;1mgas                   \e[0;90m➔ \e[32;3mrun the tests and print the gas report \e[0m\n \
		  \e[90m$$ \e[0;97;1mmake \e[0;92;1mcoverage              \e[0;90m➔ \e[32;3mrun the tests and print the coverage report \e[0m\n \
		  \e[90m$$ \e[0;97;1mmake \e[0;92;1mclean                 \e[0;90m➔ \e[32;3mremove the build artifacts and cache directories \e[0m\n \
		  \e[90m$$ \e[0;97;1mmake \e[0;92;1mupdate                \e[0;90m➔ \e[32;3mupdate the git submodules and the npm dependencies \e[0m\n \
		  \e[90m$$ \e[0;97;1mmake \e[0;92;1mhooks                 \e[0;90m➔ \e[32;3mrun the installed git hooks \e[0m\n \
		  \e[90m$$ \e[0;97;1mmake \e[0;92;1mhooks-i               \e[0;90m➔ \e[32;3minstall the git hooks defined in lefthook.yml \e[0m\n \
		  \e[90m$$ \e[0;97;1mmake \e[0;92;1mhooks-u               \e[0;90m➔ \e[32;3muninstall the git hooks defined in lefthook.yml \e[0m\n \
		  \e[90m$$ \e[0;97;1mmake \e[0;92;1mlint                  \e[0;90m➔ \e[32;3mrun the linter in check mode \e[0m\n \
		  \e[90m$$ \e[0;97;1mmake \e[0;92;1mlinter-fix              \e[0;90m➔ \e[32;3mrun the linter in write mode \e[0m\n \
		  \e[90m$$ \e[0;97;1mmake \e[0;92;1mprettier              \e[0;90m➔ \e[32;3mrun the formatter in read mode \e[0m\n \
		  \e[90m$$ \e[0;97;1mmake \e[0;92;1mprettier-fix          \e[0;90m➔ \e[32;3mrun the formatter in write mode \e[0m\n \
		  \e[90m$$ \e[0;97;1mmake \e[0;92;1mquality               \e[0;90m➔ \e[32;3mrun both the linter and the formatter in read mode \e[0m\n \
		  \e[90m$$ \e[0;97;1mmake \e[0;92;1mdoc                   \e[0;90m➔ \e[32;3mgenerate the documentation of the project \e[0m\n \
		  \e[90m$$ \e[0;97;1mmake \e[0;92;1mtree                  \e[0;90m➔ \e[32;3mdisplay a tree visualization of the project's dependency graph \e[0m\n \
		  \e[90m$$ \e[0;97;1mmake \e[0;92;1mcompute               \e[0;90m➔ \e[32;3mcompute 256 points on the secp256r1 elliptic curve\e[0m\n \
	""" | sed -e 's/^[ \t	]\{1,\}\(.\)/  \1/'


##########################################
################ COMMANDS ################
##########################################
.PHONY: forge-compile
forge-compile:
	@runcmd forge compile

.PHONY: forge-compile-size
forge-compile-size:
	@runcmd forge compile --sizes

.PHONY: forge-test
forge-test:
	@runcmd forge test

.PHONY: forge-test-verbose
forge-test-verbose:
	@runcmd forge test -vvvv

.PHONY: forge-coverage
forge-coverage:
	@runcmd forge coverage

.PHONY: forge-test-gas
forge-test-gas:
	@runcmd forge test --gas-report --no-match-test "test.*_ReportSkip|test_RevertWhen|testFuzz_RevertWhen"
# the regexp catches the tests that start with `testFuzz_RevertWhen`, `test_RevertWhen` or end with `_ReportSkip`
# stick to this convention to avoid running the gas report on tests that are not meant to be run

.PHONY: forge-clean
clean:
	@runcmd forge clean

.PHONY: forge-doc
forge-doc:
	@runcmd forge doc && forge doc --build

.PHONY: forge-tree
forge-tree:
	@runcmd forge tree --no-dedupe

.PHONY: update-dependencies
update-dependencies:
	@runcmd git submodule update --init --recursive && npm update

.PHONY: install-dependencies
install-dependencies:
	@runcmd forge install && npm install

.PHONY: lefthok-run
lefthok-run:
	@runcmd npx lefthook run pre-push

.PHONY: lefthok-install
lefthok-install:
	@runcmd npx lefthook install

.PHONY: lefthok-uninstall
lefthok-uninstall:
	@runcmd npx lefthook uninstall

.PHONY: lint
lint:
	@runcmd forge fmt --check && npx solhint "{script,src,test}/**/*.sol"

.PHONY: linter-fix
linter-fix:
	@runcmd forge fmt && npx solhint "{script,src,test}/**/*.sol" --fix

.PHONY: prettier
prettier:
	@runcmd npx prettier --check \"**/*.{json,md,yml}\"

.PHONY: prettier-fix
prettier-fix:
	@runcmd npx prettier --write \"**/*.{json,md,yml}\"

# example: `c0=XXX c1=XXX make compute`
.PHONY: compute-points
compute-points:
	@runcmd npx @smoo.th/secp256r1-computation $(c0) $(c1)

##########################################
################ ALIASES  ################
##########################################
build: forge-compile
compile: forge-compile
compile-s: forge-compile-size
test: forge-test
test-v: forge-test-verbose
gas: forge-test-gas
coverage: forge-coverage
clean: forge-clean
update: update-dependencies
doc: forge-doc
tree: forge-tree
hooks: lefthok-run
hooks-i: lefthok-install
hooks-u: lefthok-uninstall
lint: lint
lint-fix: linter-fix
format: prettier
format-fix: prettier-fix
quality: lint format
install: install-dependencies lefthok-install
compute: compute-points
