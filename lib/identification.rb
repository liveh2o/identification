module Identification
  module TableDefinitions
    def identities(*args)
      options = args.extract_options!
      column(:created_by, :integer, options)
      column(:updated_by, :integer, options)
    end
  end

  module Identifier
    def fetch_identity
      session[:current_user_id]
    end

    private    
      def identify
        unless fetch_identity.nil?
          key = controller_name.singularize.to_sym
          if params.include?(key)
            params[key] = add_identity_to_params(key,params[key])
            params[key][:_identity] = fetch_identity
          elsif params.include?(controller_name.to_sym)
            params[controller_name.to_sym].each_value do |param|
              param = add_identity_to_params(key,param)
              param[:_identity] = fetch_identity
            end
          end
        end
      end
      
      def add_identity_to_params(key,params)
        klass = key.to_s.classify.constantize
        klass.reflect_on_all_associations.each do |reflection|
          nested_attributes = "#{reflection.name}_attributes"
          if params.include?(nested_attributes)
            case reflection.macro
            when :has_one, :belongs_to
              params[nested_attributes] = add_identity_to_params(reflection.name,params[nested_attributes])
              params[nested_attributes][:_identity] = fetch_identity
            when :has_many, :has_and_belongs_to_many
              params[nested_attributes].each_value do |param|
                param = add_identity_to_params(reflection.name,param)
                param[:_identity] = fetch_identity
              end              
            end
          end
        end
        params
      end
  end
  
  module Identity
    def self.included(klass)
      klass.define_callbacks :before_identify, :after_identify
      
      klass.attr_protected :created_by, :updated_by
      klass.before_save :_identify

      klass.send :include, InstanceMethods
    end

    module InstanceMethods
      protected
        def _identity=(id)
          @_identity = id
        end
        
      private
        def _identify
          callback :before_identify
          if new_record?
            write_attribute('created_by', @_identity) if respond_to?(:created_by)
            write_attribute('updated_by', @_identity) if respond_to?(:updated_by)
          elsif !partial_updates? || changed?
            write_attribute('updated_by', @_identity) if respond_to?(:updated_by)
          end
          callback :after_identify
        end
    end
  end
end

ActiveRecord::ConnectionAdapters::Table.send(:include,Identification::TableDefinitions)
ActiveRecord::Base.send(:include, Identification::Identity)
ActionController::Base.send(:include,Identification::Identifier)