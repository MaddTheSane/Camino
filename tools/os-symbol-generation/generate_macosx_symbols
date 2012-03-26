#!/usr/bin/ruby
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

require 'fileutils'
require 'open3'

if ARGV.length != 3
  puts <<EOF
Usage: #{$0} <symbolstore.py path> <dump_syms path> <output directory>

Reads a list of binaries/libraries from STDIN and generates symbols for all
of them in <output directory>. Lines beginning with # are ignored, so an input
file can contain comments.
EOF
  exit 1
end
(symbolstore_py_path, dump_syms_path, output_dir) = ARGV

os_version = `sw_vers -productVersion`.chomp.gsub('.', '_')
os_build = `sw_vers -buildVersion`.chomp
symbol_output_dir = File.join(output_dir, "macosx-#{os_version}-#{os_build}-symbols")
symbol_archive_basename = "Mac_OS_X-#{os_version}-#{os_build}"
symbol_list_file = File.join(symbol_output_dir, "#{symbol_archive_basename}-symbols.txt")
zip_archive_file = "crashreporter-symbols-#{symbol_archive_basename}.zip"

binaries = $stdin.readlines.reject {|line| line.match("^#") }

# These won't be going through a shell, so take care of globbing ourselves.
binaries.collect! { |path| Dir.glob(path.chomp) }.flatten!

puts "Breakpad symbols for Mac OS X #{os_version}"

puts "Preparing symbol storage directory"
FileUtils.mkdir_p symbol_output_dir

puts "\nGenerating OS symbols"
Open3.popen3("python", symbolstore_py_path, "-a", "ppc i386", "--no-dsym", dump_syms_path, symbol_output_dir, *binaries) do |stdin, stdout, stderr| 
  symbol_list_buffer = ""
  # Use a very long timeout, since symbolstore.py buffers output.
  while ready_sources = IO.select([stdout, stderr], nil, nil, 300)
    still_reading = false
    for source in ready_sources[0]
      output = ""
      begin
        output = source.readpartial(4096)
      rescue EOFError
        next
      end
      next if output.nil?
      still_reading = true
      if source == stdout 
        symbol_list_buffer += output
      else
        print output
      end
    end
    break if not still_reading
  end
  File.open(symbol_list_file, "w") { |file| file.write(symbol_list_buffer) }
end

puts "\nZipping symbols"
system("cd '#{symbol_output_dir}' && zip -r9D '../#{zip_archive_file}' .")

puts "\nMac OS X #{os_version} symbols generated in #{symbol_output_dir}"
puts "Mac OS X #{os_version} symbol archive generated in #{output_dir}/#{zip_archive_file}"
