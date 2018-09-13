require 'rake/packagetask'

Rake::PackageTask.new("slackpad-server", :noversion) do |p|
  p.package_dir = "./tmp/packaging"
  files = `git ls-files`.split.reject{|path| %r"\A(?:itamae)/" =~ path }
  p.package_files.include(files)
  p.need_tar_gz = true
end
