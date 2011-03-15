require 'pathname'
require 'fileutils'

module ActiveSchema
  module ActiveRecord
    module Manifest

      protected

      def create_manifest
        env = Rails.env rescue "test"
        manifest_logger if Array.wrap(active_schema_config.manifest.logger_environments).collect(&:to_s).include? env
        manifest_rdoc if Array.wrap(active_schema_config.manifest.rdoc_environments).collect(&:to_s).include? env
      end

      public

      def manifest_logger
        logger.info "Manifest\n" + manifest
      end

      def manifest_rdoc
        root = Rails.root rescue "."
        path = Pathname(root) + active_schema_config.manifest.rdoc_path
        filename = (name.blank? ? "anonymous_#{self.object_id}" : name).underscore

        FileUtils.mkdir_p(path)
        File.open("#{path}/#{filename}.rdoc", "w") do |file|
          manifest(file)
        end
      end

      def manifest(stream=nil)
        stream ||= StringIO.new
        stream.puts "= class #{name.blank? ? "<Anonymous Model>" : name}"
        stream.puts

        if (columns = self.columns).any?
          types = connection.native_database_types
          indexes = self.indexes.dup
          foreign_keys = self.foreign_keys.dup
          stream.puts "== columns"
          # cribbed from AR schema_dumper.rb ...
          columns.each do |column|
            # AR has an optimisation which handles zero-scale decimals as integers.  This
            # code ensures that the dumper still dumps the column as a decimal.
            type = case
                   when column.name == primary_key then 'primary'
                   when column.type == :integer && [/^numeric/, /^decimal/].any? { |e| e.match(column.sql_type) } then 'decimal'
                   else column.type
                   end
            stream.print "* #{type} #{column.name.to_sym.inspect}"
            stream.print ", :limit => #{column.limit.inspect}" if column.limit != types[column.type][:limit] && type != 'decimal'
            stream.print ", :precision => #{column.precision.inspect}" unless column.precision.nil?
            stream.print ", :scale => #{column.scale.inspect}" unless column.scale.nil?
            stream.print ", :null => false" unless column.null
            if column.has_default?
              stream.print ", :default => " + case value = column.default
              when BigDecimal
                value.to_s
              when Date, DateTime, Time
                "'" + value.to_s(:db) + "'"
              else
                value.inspect
              end
            end
            if foreign_key = foreign_keys.select{|fk| fk.column_names == [ column.name ]}.first
              foreign_keys.delete(foreign_key)
              stream.print ", :references => [#{foreign_key.references_table_name.to_sym.inspect}, #{foreign_key.references_column_names.first.to_sym.inspect}]"
              stream.print ", :on_update => #{foreign_key.on_update.inspect}" if foreign_key.on_update
              stream.print ", :on_delete => #{foreign_key.on_delete.inspect}" if foreign_key.on_delete
            end
            if index = indexes.select{|idx| idx.columns.include? column.name}.sort_by{|idx| idx.columns.length}.first
              indexes.delete(index)
              opts = index.opts.dup
              opts[:with] = (index.columns - [column.name]).collect(&:to_sym) if index.columns.length > 1
              stream.print ", :index => #{_pp_options(opts, :braces => true)}"
            end
            stream.puts
          end
          stream.puts

          if indexes.any?
            stream.puts "== additional indexes"
            indexes.each do |index|
              stream.puts "* index #{index.columns.collect(&:to_sym).inspect}#{_pp_options(index.opts, :symbolize_values => true)}"
            end
            stream.puts
          end
          if foreign_keys.any?
            stream.puts "== additional foreign keys"
            foreign_keys.each do |foreign_key|
              stream.print "* foreign_key #{foreign_key.column_names.collect(&:to_sym).inspect}, #{foreign_key.references_table_name.to_sym.inspect}, #{foreign_key.references_column_names.collect(&:to_sym)}.inspect"
              stream.print ", :on_update => #{foreign_key.on_update.inspect}" if foreign_key.on_update
              stream.print ", :on_delete => #{foreign_key.on_delete.inspect}" if foreign_key.on_delete
              stream.puts
            end
            stream.puts
          end
        end

        if (aggregations = reflect_on_all_aggregations).any?
          stream.puts "== aggregations"
          aggregations.sort_by{|aggregation| aggregation.name.to_s}.each do |aggregation|
            stream.puts "* #{aggregation.macro} #{aggregation.name.inspect}#{_pp_options(aggregation.options)}"
          end
          stream.puts
        end

        if (associations = reflect_on_all_associations).any?
          stream.puts "== associations"
          associations.sort_by{|association| association.name.to_s}.each do |association|
            stream.puts "* #{association.macro} #{association.name.inspect}#{_pp_options(association.options)}"
          end
          stream.puts
        end

        if (validations = _validate_callbacks).any?
          stream.puts "== validations"
          validations.each do |validation|
            raw_filter = validation.raw_filter
            filter = raw_filter
            filter = raw_filter.kind.to_s if raw_filter.respond_to? :kind
            if raw_filter.respond_to? :attributes
              if (attrs = raw_filter.attributes).length == 1
                filter += " #{attrs.first.inspect}"
              else
                filter += " #{attrs.inspect}"
              end
            end
            stream.puts "* #{filter}#{_pp_options(validation.options, :symbolize_values => true)}"
          end
          stream.puts
        end

        return stream.string if stream.respond_to? :string
      end

      private

      def _pp_options(options, ppopts={})
        str = options.keys.sort_by(&:to_s).collect{|key|
          value = options[key]
          valstr = case 
                   when value.blank?
                     nil
                   when String === value
                     value = value.to_sym if ppopts[:symbolize_values]
                     value.inspect
                   when Hash === value
                     _pp_options(value, :braces => true)
                   else
                     value.inspect.sub(/:0x[0-9a-f]+/, '')
                   end
          ":#{key}=>#{valstr}" unless valstr.blank?
        }.compact.join(", ")
        if ppopts[:braces]
          str = "{"+str+"}"
        else
          str = ", " + str unless str.blank?
        end
        str
      end

    end
  end
end
