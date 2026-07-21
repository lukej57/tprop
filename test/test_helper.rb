# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"

require "tprop"
require "tprop/minitest"

# Keep the suite hermetic: the default example database is in-memory, so
# running the tests never writes a .tprop-cache/ into the repo. The FileDatabase
# is exercised explicitly (in a temp dir) by database_test.rb.
TProp.default_database = TProp::MemoryDatabase.new
