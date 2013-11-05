require 'spec_helper'

shared_examples_for 'renderable' do
  it "should not exist" do
    subject.exists?.should be_false
  end
  describe '#render' do
    before { subject.render(source_file) }
    it "should exist" do
      subject.exists?.should be_true
    end
    it "should have added the prefix" do
      dest_file.read.should =~ Babushka::Renderable::SEAL_REGEXP
    end
    it "should have interpolated the erb" do
      dest_file.read.should =~ content
    end
    describe "#clean?" do
      it "should be clean" do
        subject.should be_clean
      end
      context "after shitting up the file" do
        before {
          Babushka::ShellHelpers.shell "echo lulz >> #{subject.path}"
        }
        it "should not be clean" do
          subject.should_not be_clean
        end
      end
    end
    describe '#from?' do
      it "should be from the same content" do
        subject.should be_from(source_file)
      end
      it "should not be from different content" do
        subject.should_not be_from('spec/renderable/different_example.conf.erb')
      end
    end
  end
end

describe Babushka::Renderable do
  subject { Babushka::Renderable.new(dest_file) }

  describe '#source_sha' do
    context "when the result doesn't exist" do
      let(:dest_file) { tmp_prefix / 'missing.conf' }
      it "should raise an error" do
        L{ subject.source_sha }.should raise_error(Errno::ENOENT)
      end
    end
    context "when the result is an empty file" do
      let(:dest_file) {
        (tmp_prefix / 'empty.conf').tap {|p| p.write "" }
      }
      it "should return nil" do
        subject.source_sha.should == nil
      end
    end
    context "when the result doesn't contain an Inkan seal" do
      let(:dest_file) {
        (tmp_prefix / 'empty.conf').tap {|p| p.write "Holy lols" }
      }
      it "should return nil" do
        subject.source_sha.should == nil
      end
    end
    context "when the result is a rendered file" do
      let(:dest_file) {
        (tmp_prefix / 'empty.conf').tap {|p| p.write "# Generated by babushka-0.10.5 at 2011-10-24 16:02:08 +1100, from 8af66582dbd74858c701fcdeabafca06798cafc2. 2d73ecb845d6459e6390ab6aabbac146a020c022" }
      }
      it "should return the correct sha" do
        subject.source_sha.should == '8af66582dbd74858c701fcdeabafca06798cafc2'
      end
    end
  end

  context "with a config file" do
    let(:source_file) { "spec/renderable/example.conf.erb" }
    let(:dest_file) { tmp_prefix / 'example.conf' }
    let(:content) { %r{root #{tmp_prefix};} }
    it_should_behave_like 'renderable'
  end
  context "with an xml file" do
    let(:source_file) { "spec/renderable/xml_example.conf.erb" }
    let(:dest_file) { tmp_prefix / 'xml_example.conf' }
    let(:content) { %r{<key>Lol</key>} }
    it_should_behave_like 'renderable'
    context "custom comment" do
      before { subject.render(source_file, :comment => '<!--', :comment_suffix => '-->') }
      it "should have rendered an xml comment in the output" do
        dest_file.read.should =~ %r{<!-- Generated by babushka-[\d\.]+ at [^,]+, from \w{40}\. \w{40} -->}
      end
      after { dest_file.rm }
    end
  end
  context "with a script containing a shebang" do
    let(:source_file) { "spec/renderable/example.sh" }
    let(:dest_file) { tmp_prefix / 'example.sh' }
    let(:content) { %r{babushka 'benhoskings:up to date.repo'} }
    it_should_behave_like 'renderable'
  end
end

describe "binding handling" do
  subject { Babushka::Renderable.new(tmp_prefix / 'example.conf') }
  context "when no explicit binding is passed" do
    before {
      subject.instance_eval {
        def custom_renderable_path
          "from implicit binding"
        end
      }
      subject.render('spec/renderable/with_binding.conf.erb')
    }
    it "should render using the implicit binding" do
      (tmp_prefix / 'example.conf').read.should =~ /from implicit binding/
    end
  end
  context "when an explicit binding is passed" do
    before {
      dep 'renderable binding spec' do
        def custom_renderable_path
          "from explicit binding"
        end
      end.met?
      subject.render('spec/renderable/with_binding.conf.erb', :context => Dep('renderable binding spec').context)
    }
    it "should render using the given binding" do
      (tmp_prefix / 'example.conf').read.should =~ /from explicit binding/
    end
  end
end
