TEST_EXTENSIONS += .cargo
CARGO_LOG_DRIVER = env top_builddir="${abs_top_builddir}" \
                   $(abs_top_srcdir)/buildsystem/cargo-test.py \
                   --working-directory="${abs_top_srcdir}/src/rust/"

vlcrs-macros.cargo:
vlcrs-messages.cargo:
vlcrs-plugin.cargo:
vlcrs-utils.cargo:
	env top_builddir="${abs_top_builddir}" \
	$(RUST_ENV) $(CARGO) -C $(top_srcdir)/src/rust/$(@:.cargo=) --target=$(RUST_TARGET) build

if HAVE_RUST
TESTS += \
	vlcrs-macros.cargo \
	vlcrs-messages.cargo \
	vlcrs-plugin.cargo \
	vlcrs-utils.cargo
endif
