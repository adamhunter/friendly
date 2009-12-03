require File.expand_path("../../spec_helper", __FILE__)
require File.expand_path("../../fakes/document", __FILE__)

describe "Friendly::Repository" do
  before do
    @index_stub = stub(:table_name => "index_users_on_name", :fields => [:name])
    @as_hash   = {:name       => "Stewie",
                  :id         => nil,
                  :created_at => nil,
                  :updated_at => nil}
    @doc = FakeDocument.new(:table_name => "users",
                            :new_record => true,
                            :id         => nil,
                            :name       => "Stewie",
                            :indexes    => [@index_stub],
                            :to_hash    => @as_hash)
               
    @json          = "THE JSONS"
    @serializer    = stub
    @serializer.stubs(:generate).with({:name => "Stewie"}).returns(@json)
    @id            = 5
    @dataset       = stub(:insert   => @id)
    @index_dataset = stub(:insert => nil)
    @database      = stub
    @database.stubs(:from).with("users").returns(@dataset)
    @database.stubs(:from).with("index_users_on_name").returns(@index_dataset)
    @time          = Time.new
    @persister     = stub(:save => true)
    @repository    = Friendly::Repository.new(@database, @serializer, @persister)
  end

  context "Saving a document" do
    before do
      @repository.save(@doc)
    end

    it "delegates to the persister" do
      @persister.should have_received(:save).with(@doc)
    end
  end

  describe "finding an object by id" do
    before do
      @parsed_hash = {:name => "Stewie"}
      @serializer.stubs(:parse).returns(@parsed_hash)
      @dataset.stubs(:first).returns(:attributes => @json, 
                                     :id         => 1, 
                                     :created_at => @time,
                                     :updated_at => @time)
      @klass = stub(:table_name => "users", :new => @doc)
      @returned_doc = @repository.find(@klass, 1)
    end

    it "finds in the table" do
      @dataset.should have_received(:first).with(:id => 1)
    end

    it "uses the serializer to parse the json" do
      @serializer.should have_received(:parse).with(@json)
    end

    it "instantiates an object of type @klass with the resulting hash" do
      extra_attrs = {:id => 1, :created_at => @time, :updated_at => @time}
      @klass.should have_received(:new).with(@parsed_hash.merge(extra_attrs))
    end

    it "returns the document" do
      @returned_doc.should == @doc
    end
  end

  describe "finding a non-existant object by id" do
    before do
      Friendly.config.repository = @repository
      @dataset.stubs(:first).returns(nil)
    end

    it "raises Friendly::RecordNotFound" do
      lambda { User.find(1) }.should raise_error(Friendly::RecordNotFound)
    end
  end

  describe "finding multiple objects by id" do
    before do
      @obj   = stub
      @klass = stub(:new => @obj, :table_name => "users", :name => "User")
    end

    describe "when all the objects are found" do
      before do
        @serializer.stubs(:parse).returns({})
        @dataset.stubs(:where).returns([{:id => 1, :attributes => "{}"}, 
                                        {:id => 2, :attributes => "{}"}])
        @return = @repository.find(@klass, 1,2)
      end

      it "returns objects of klass" do
        @klass.should have_received(:new).with(:id         => 1, 
                                               :created_at => nil, 
                                               :updated_at => nil)
        @klass.should have_received(:new).with(:id         => 2,
                                               :created_at => nil,
                                               :updated_at => nil)
        @return.should == [@obj, @obj]
      end

      it "deserializes the attributes" do
        @serializer.should have_received(:parse).with("{}").twice
      end
    end
    
    describe "when no objects are found" do
      before do
        @dataset.stubs(:where).returns([])
      end

      it "raises record not found" do
        lambda {
          @repository.find(@klass, 1, 2, 3) 
        }.should raise_error(Friendly::RecordNotFound)
      end
    end
  end
end
