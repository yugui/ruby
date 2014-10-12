require 'fileutils'
require 'find'
def run(extmk)
  dir = "tmp/x86_64-darwin/#{extmk}"
  FileUtils.rm_rf File.join(dir, 'ext')
  FileUtils.mkdir_p File.join(dir, 'ext')
  Dir.chdir(dir) {
    argv = %W[
      ./miniruby
      -I../../../lib
      -I.
      -I./common
      ../../../ext/#{extmk}
      --command-output=exts.mk
      --dest-dir=
      --extout=.
      --with-extensions=bigdecimal,etc,dl,fiddle,dbm,readline,sdbm,zlib,ripper,socket
      --mflags=
      --make-flags=V=1
      --extension
      --extstatic
      --make-flags=V=1\ MINIRUBY='./miniruby\ -I../../../lib\ -I.\ -I./common'
      --gnumake=yes
      -- configure
    ]
    system(*argv) || raise(argv.join(" "))
  }
  Find.find(File.join(dir, 'ext')) do |ent|
    if File.basename(ent) == "mkmf.log"
      FileUtils.rm ent
    end
  end
end

run("extmk.rb")
run("extmk.orig.rb")

exit *system("diff -u -r tmp/x86_64-darwin/extmk.orig.rb tmp/x86_64-darwin/extmk.rb")
