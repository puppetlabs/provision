require 'fileutils'

RSpec.configure do |rspec|
  rspec.expect_with :rspec do |c|
    c.max_formatted_output_length = nil
  end
end

RSpec.shared_context('with tmpdir') do
  let(:tmpdir) { @tmpdir } # rubocop:disable RSpec/InstanceVariable

  around(:each) do |example|
    Dir.mktmpdir('rspec-provision_test') do |t|
      FileUtils.mkdir_p(File.join(t, 'spec', 'fixtures'))
      @tmpdir = t
      example.run
    end
  end
end
