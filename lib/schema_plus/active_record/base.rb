module SchemaPlus
  module ActiveRecord
    module Base
      def self.included(base)
        base.extend(ClassMethods)
        base.extend(SchemaPlus::ActiveRecord::Associations)
        base.extend(SchemaPlus::ActiveRecord::Validations)
      end

      module ClassMethods
        def self.extended(base)
          class << base
            alias_method_chain :columns, :schema_plus
            alias_method_chain :abstract_class?, :schema_plus
            alias_method_chain :reset_column_information, :schema_plus
          end
        end

        public

        # class decorator
        def schema_plus(opts)
          @schema_plus_config = SchemaPlus.config.merge(opts)
        end

        def abstract_class_with_schema_plus?
          abstract_class_without_schema_plus? || !(name =~ /^Abstract/).nil?
        end

        def columns_with_schema_plus
          unless @columns
            @columns = columns_without_schema_plus
            cols = columns_hash
            indexes.each do |index|
              next if index.columns.blank?
              column_name = index.columns.reverse.detect { |name| name !~ /_id$/ } || index.columns.last
              column = cols[column_name]
              column.case_sensitive = index.case_sensitive?
              column.unique_scope = index.columns.reject { |name| name == column_name } if index.unique
            end
          end
          @columns
        end

        def reset_column_information_with_schema_plus
          reset_column_information_without_schema_plus
          @indexes = @foreign_keys = nil
        end

        def indexes
          @indexes ||= connection.indexes(table_name, "#{name} Indexes")
        end

        def foreign_keys
          @foreign_keys ||= connection.foreign_keys(table_name, "#{name} Foreign Keys")
        end

        def reverse_foreign_keys
          connection.reverse_foreign_keys(table_name, "#{name} Reverse Foreign Keys")
        end

        def schema_plus_config
          @schema_plus_config ||= SchemaPlus.config.dup
        end
      end
    end
  end
end
