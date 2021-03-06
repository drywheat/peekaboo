require File.expand_path('../spec_helper', __FILE__)

describe Peekaboo do
  
  context "configuration" do
    it "should be properly referenced" do
      Peekaboo.configuration.should be_an_instance_of Peekaboo::Configuration
    end
    
    it "should yield itself" do
      yielded_object = nil
      Peekaboo.configure { |x| yielded_object = x }
      Peekaboo.configuration.should == yielded_object
    end
  end
  
  context "enabling tracing" do
    before(:each) do
      @tracer = Peekaboo.configuration.tracer
      @test_class = new_test_class.instance_eval { include Peekaboo }
      @test_class.enable_tracing_for :singleton_methods => [:say_hello, :hello, :add, :happy?, :comma_list, :kaboom],
                                     :instance_methods  => [:say_goodbye, :goodbye, :subtract, :sad?, :pipe_list, :crash]
    end
    
    it "should guard its map of traced methods" do
      lambda {
        @test_class.traced_method_map[:something] = 'unwanted'
      }.should raise_exception
    end
    
    it "should store a list of traced methods" do
      @test_class.traced_singleton_methods.should include :say_hello, :hello, :add, :happy?, :comma_list, :kaboom
      @test_class.traced_instance_methods.should include :say_goodbye, :goodbye, :subtract, :sad?, :pipe_list, :crash
    end
    
    it "should ensure that traced methods are uniquely stored" do
      lambda {
        @test_class.enable_tracing_for :singleton_methods => [:say_hello]
      }.should_not change(@test_class.traced_singleton_methods, :size).from(6)
      
      lambda {
        @test_class.enable_tracing_for :singleton_methods => [:object_id]
      }.should change(@test_class.traced_singleton_methods, :size).from(6).to(7)
      
      lambda {
        @test_class.enable_tracing_for :instance_methods => [:say_goodbye]
      }.should_not change(@test_class.traced_instance_methods, :size).from(6)
      
      lambda {
        @test_class.enable_tracing_for :instance_methods => [:object_id]
      }.should change(@test_class.traced_instance_methods, :size).from(6).to(7)
    end
    
    context "on class methods" do
      it "should not take place on unlisted methods" do
        @tracer.should_not_receive :info
        @test_class.object_id
      end
      
      it "should show listed methods with no arguments" do
        @tracer.should_receive(:info).
          with trace_message %{Invoking: #{@test_class}.say_hello with [] ==> Returning: "hello"}
        @test_class.say_hello
      end
      
      it "should show listed methods with required arguments" do
        @tracer.should_receive(:info).
          with trace_message %{Invoking: #{@test_class}.hello with ["developer"] ==> Returning: "hello developer"}
        @test_class.hello 'developer'
        
        @tracer.should_receive(:info).
          with trace_message %{Invoking: #{@test_class}.add with [1, 2] ==> Returning: 3}
        @test_class.add 1, 2
      end
      
      it "should show methods with optional arguments" do
        @tracer.should_receive(:info).
          with trace_message %{Invoking: #{@test_class}.happy? with [] ==> Returning: true}
        @test_class.happy?
        
        @tracer.should_receive(:info).
          with trace_message %{Invoking: #{@test_class}.happy? with [false] ==> Returning: false}
        @test_class.happy? false
      end
      
      it "should show methods with variable arguments" do
        @tracer.should_receive(:info).
          with trace_message %{Invoking: #{@test_class}.comma_list with [] ==> Returning: ""}
        @test_class.comma_list
        
        @tracer.should_receive(:info).
          with trace_message %{Invoking: #{@test_class}.comma_list with [:too, "cool"] ==> Returning: "too,cool"}
        @test_class.comma_list :too, 'cool'
        
        @tracer.should_receive(:info).
          with trace_message %{Invoking: #{@test_class}.comma_list with [1, "to", 5] ==> Returning: "1,to,5"}
        @test_class.comma_list 1, 'to', 5
      end
      
      it "should show methods that raise an exception" do
        lambda do
          @tracer.should_receive(:info).
            with trace_message %{Invoking: #{@test_class}.kaboom with [] !!! Raising: "fire, fire"}
          @test_class.kaboom
        end.should raise_exception
      end
    
      it "should work when methods are added after the fact" do
        @test_class.enable_tracing_for :singleton_methods => [:dog]
        def @test_class.dog
          'woof'
        end
        
        @tracer.should_receive(:info).
          with trace_message %{Invoking: #{@test_class}.dog with [] ==> Returning: "woof"}
        @test_class.dog
      end
    end
    
    context "on instance methods" do
      before(:each) do
        @test_instance = @test_class.new
      end

      it "should not take place on unlisted methods" do
        @tracer.should_not_receive :info
        @test_instance.object_id
      end
      
      it "should show listed methods with no arguments" do
        @tracer.should_receive(:info).
          with trace_message %{Invoking: #{@test_class}#say_goodbye with [] ==> Returning: "goodbye"}
        @test_instance.say_goodbye
      end
      
      it "should show listed methods with required arguments" do
        @tracer.should_receive(:info).
          with trace_message %{Invoking: #{@test_class}#goodbye with ["bugs"] ==> Returning: "goodbye bugs"}
        @test_instance.goodbye 'bugs'
      
        @tracer.should_receive(:info).
          with trace_message %{Invoking: #{@test_class}#subtract with [5, 4] ==> Returning: 1}
        @test_instance.subtract 5, 4
      end
      
      it "should show methods with optional arguments" do
        @tracer.should_receive(:info).
          with trace_message %{Invoking: #{@test_class}#sad? with [] ==> Returning: false}
        @test_instance.sad?
      
        @tracer.should_receive(:info).
          with trace_message %{Invoking: #{@test_class}#sad? with [true] ==> Returning: true}
        @test_instance.sad? true
      end
      
      it "should show methods with variable arguments" do
        @tracer.should_receive(:info).
          with trace_message %{Invoking: #{@test_class}#pipe_list with [] ==> Returning: ""}
        @test_instance.pipe_list
        
        @tracer.should_receive(:info).
          with trace_message %{Invoking: #{@test_class}#pipe_list with [:alf, "is"] ==> Returning: "alf|is"}
        @test_instance.pipe_list :alf, "is"
        
        @tracer.should_receive(:info).
          with trace_message %{Invoking: #{@test_class}#pipe_list with [:alf, "is", 0] ==> Returning: "alf|is|0"}
        @test_instance.pipe_list :alf, "is", 0
      end
      
      it "should show methods that raise an exception" do
        lambda do
          @tracer.should_receive(:info).
            with trace_message %{Invoking: #{@test_class}#crash with [] !!! Raising: "twisted code"}
          @test_instance.crash
        end.should raise_exception
      end

      it "should work when methods are added after the fact" do
        @test_class.enable_tracing_for :instance_methods => [:frog]
        @test_class.class_eval do
          def frog
            'ribbit'
          end
        end
        
        @tracer.should_receive(:info).
          with trace_message %{Invoking: #{@test_class}#frog with [] ==> Returning: "ribbit"}
        @test_instance.frog
      end
    end
  end
  
  context "autoinclusion tracing" do
    before(:each) do
      @tracer = Peekaboo.configuration.tracer
      @base_class = new_test_class
      Peekaboo.configure { |config| config.autoinclude_with @base_class }
    end
    
    context "on class methods" do
      it "should inject functionality into an auto-included class" do
        @base_class.enable_tracing_for :singleton_methods => [:say_hello]
        
        @tracer.should_receive(:info).
          with trace_message %{Invoking: #{@base_class}.say_hello with [] ==> Returning: "hello"}
        @base_class.say_hello
      end

      it "should inject functionality into any class that inherits from an auto-included class" do
        child_class = Class.new(@base_class) { def self.say_hola; 'hola'; end }
        child_class.enable_tracing_for :singleton_methods => [:say_hola]
        
        @tracer.should_receive(:info).
          with trace_message %{Invoking: #{child_class}.say_hola with [] ==> Returning: "hola"}
        child_class.say_hola
      end

      it "should not inject functionality into classes that are not auto-included" do
        not_a_child_class = new_test_class
        lambda {
         not_a_child_class.enable_tracing_for :singleton_methods => [:say_hello]
        }.should raise_exception NoMethodError
      end

      it "should maintain unique tracing method lists across an inheritance chain" do
        child_class = Class.new(@base_class) { def self.say_hola; 'hola'; end }
        @base_class.enable_tracing_for :singleton_methods => [:say_hello]
        child_class.enable_tracing_for :singleton_methods => [:say_hola]

        @base_class.traced_singleton_methods.to_a.should =~ [:say_hello]
        child_class.traced_singleton_methods.to_a.should =~ [:say_hola]
      end
    end
    
    context "on instance methods" do
      it "should inject functionality into an auto-included class" do
        @base_class.enable_tracing_for :instance_methods => [:say_goodbye]
        
        @tracer.should_receive(:info).
          with trace_message %{Invoking: #{@base_class}#say_goodbye with [] ==> Returning: "goodbye"}
        @base_class.new.say_goodbye
      end

      it "should inject functionality into any class that inherits from an auto-included class" do
        child_class = Class.new(@base_class) { def say_adios; 'adios'; end }
        child_class.enable_tracing_for :instance_methods => [:say_adios]
        
        @tracer.should_receive(:info).
          with trace_message %{Invoking: #{child_class}#say_adios with [] ==> Returning: "adios"}
        child_class.new.say_adios
      end

      it "should not inject functionality into classes that are not auto-included" do
        not_a_child_class = new_test_class
        lambda {
         not_a_child_class.enable_tracing_for :instance_methods => [:say_goodbye]
        }.should raise_exception NoMethodError
      end

      it "should maintain unique tracing method lists across an inheritance chain" do
        child_class = Class.new(@base_class) { def say_adios; 'adios'; end }
        @base_class.enable_tracing_for :instance_methods => [:say_goodbye]
        child_class.enable_tracing_for :instance_methods => [:say_adios]

        @base_class.traced_instance_methods.to_a.should =~ [:say_goodbye]
        child_class.traced_instance_methods.to_a.should =~ [:say_adios]
      end
    end
  end
  
  context "disabling tracing" do
    before(:each) do
      @tracer = Peekaboo.configuration.tracer
      @test_class = new_test_class.instance_eval { include Peekaboo }
      @test_class.enable_tracing_for :singleton_methods => [:say_hello, :hello, :add, :happy?, :comma_list, :kaboom],
                                     :instance_methods  => [:say_goodbye, :goodbye, :subtract, :sad?, :pipe_list, :crash]
    end
    
    it "should not raise an exception when methods do not exist and have not been pre-registered" do
      methods = { :singleton_methods => [:missing_class_def], :instance_methods => [:missing_instance_def] }
      lambda { @test_class.disable_tracing_for methods }.should_not raise_exception
    end
    
    it "should not raise an exception when methods do not exist and have been pre-registered" do
      methods = { :singleton_methods => [:missing_class_def], :instance_methods => [:missing_instance_def] }
      @test_class.enable_tracing_for methods
      lambda { @test_class.disable_tracing_for methods }.should_not raise_exception
    end
    
    context "on class methods" do
      it "should remove the method name for the list of traced methods" do
        lambda {
          @test_class.disable_tracing_for :singleton_methods => [:say_hello]
        }.should change(@test_class.traced_singleton_methods, :size).by(-1)
        
        lambda {
          @test_class.disable_tracing_for :singleton_methods => [:hello, :add]
        }.should change(@test_class.traced_singleton_methods, :size).by(-2)
      end

      it "should properly restore the original method to an untraced state" do
        @test_class.disable_tracing_for :singleton_methods => [:say_hello]
        @tracer.should_not_receive :info
        @test_class.say_hello.should == 'hello'
        
        @test_class.disable_tracing_for :singleton_methods => [:hello, :add]
        @tracer.should_not_receive :info
        @test_class.hello('you').should == 'hello you'
        @test_class.add(5, 4).should == 9
      end
    end
    
    context "on instance methods" do
      before(:each) do
        @test_instance = @test_class.new
      end
      
      it "should remove the method name for the list of traced methods" do
        lambda {
          @test_class.disable_tracing_for :instance_methods => [:say_goodbye]
        }.should change(@test_class.traced_instance_methods, :size).by(-1)
        
        lambda {
          @test_class.disable_tracing_for :instance_methods => [:goodbye, :subtract]
        }.should change(@test_class.traced_instance_methods, :size).by(-2)
      end

      it "should properly restore the original method to an untraced state" do
        @test_class.disable_tracing_for :instance_methods => [:say_goodbye]
        @tracer.should_not_receive :info
        @test_instance.say_goodbye.should == 'goodbye'
        
        @test_class.disable_tracing_for :instance_methods => [:goodbye, :subtract]
        @tracer.should_not_receive :info
        @test_instance.goodbye('mother').should == 'goodbye mother'
        @test_instance.subtract(100, 99).should == 1
      end
    end
  end
  
end
