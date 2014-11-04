require 'spec_helper'

describe ActiveFedora::Datastream do
  let(:parent) { double('inner object', uri: "#{ActiveFedora.fedora.host}#{ActiveFedora.fedora.base_path}/1234", id: '1234', new_record?: true) }
  let(:datastream) { ActiveFedora::Datastream.new(parent, 'abcd') }

  subject { datastream }

  it { should_not be_metadata }

  describe "#behaves_like_io?" do
    subject { datastream.send(:behaves_like_io?, object) }

    context "with a File" do
      let(:object) { File.new __FILE__ }
      it { should be true }
    end

    context "with a Tempfile" do
      after { object.close; object.unlink }
      let(:object) { Tempfile.new('foo') }
      it { should be true }
    end

    context "with a StringIO" do
      let(:object) { StringIO.new('foo') }
      it { should be true }
    end
  end

  describe "to_param" do
    before { allow(subject).to receive(:dsid).and_return('foo.bar') }
    it "should escape dots" do
      expect(subject.to_param).to eq 'foo%2ebar'
    end
  end

  describe "#generate_dsid" do
    let(:parent) { double('inner object', uri: "#{ActiveFedora.fedora.host}#{ActiveFedora.fedora.base_path}/1234", id: '1234',
                          new_record?: true, attached_files: datastreams) }

    subject { ActiveFedora::Datastream.new(parent, nil, prefix: 'FOO') }

    let(:datastreams) { { } }

    it "should set the dsid" do
      expect(subject.dsid).to eq 'FOO1'
    end

    it "should set the uri" do
      expect(subject.uri).to eq "#{ActiveFedora.fedora.host}#{ActiveFedora.fedora.base_path}/1234/FOO1"
    end

    context "when some datastreams exist" do
      let(:datastreams) { {'FOO56' => double} }

      it "should start from the highest existing dsid" do
        expect(subject.dsid).to eq 'FOO57'
      end
    end
  end

  context "content" do
    
    let(:mock_conn) do
      Faraday.new do |builder|
        builder.adapter :test, conn_stubs do |stub|
        end
      end
    end

    let(:mock_client) do
      Ldp::Client.new mock_conn
    end

    let(:conn_stubs) do
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.head('/fedora/rest/test/1234/abcd') { [200, {'Content-Length' => '9999' }] }
      end
    end

    before do
      allow(subject).to receive(:ldp_connection).and_return(mock_client)
    end

    describe ".size" do
      it "should load the datastream size attribute from the fedora repository" do
        expect(subject.size).to eq 9999
      end
    end

    describe ".empty?" do
      it "should not be empty" do
        expect(subject.empty?).to be false
      end
    end

    describe ".has_content?" do
      context "when there's content" do
        it "should return true" do
          expect(subject.has_content?).to be true
        end
      end
      context "when content is nil" do
        let(:conn_stubs) do
          Faraday::Adapter::Test::Stubs.new do |stub|
            stub.head('/fedora/rest/test/1234/abcd') { [200] }
          end
        end
        it "should return false" do
          expect(subject.has_content?).to be false
        end
      end
      context "when content is zero" do
        let(:conn_stubs) do
          Faraday::Adapter::Test::Stubs.new do |stub|
            stub.head('/fedora/rest/test/1234/abcd') { [200, {'Content-Length' => '0' }] }
          end
        end
        it "should return false" do
          expect(subject.has_content?).to be false
        end
      end 
    end
  
  end

  context "when the datastream has local content" do

    before do
      datastream.content = "hi there"
    end

    describe "#inspect" do
      subject { datastream.inspect }
      it { should eq "#<ActiveFedora::Datastream uri=\"http://localhost:8983/fedora/rest/test/1234/abcd\" >" }
    end
  end

  context "original_name" do
    subject { datastream.original_name }

    context "on a new datastream" do
      before { datastream.original_name = "my_image.png" }
      it { should eq "my_image.png" }
    end

    context "when it's saved" do
      let(:parent) { ActiveFedora::Base.create }
      before do
        p = parent
        p.add_file_datastream('one1two2threfour', dsid: 'abcd', mime_type: 'video/webm', original_name: "my_image.png")
        parent.save!
      end

      it "should have original_name" do
        expect(parent.reload.abcd.original_name).to eq 'my_image.png'
      end
    end
  end
end