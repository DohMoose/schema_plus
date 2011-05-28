require 'tsort'

module SchemaPlus
  module ActiveRecord
    module SchemaDumper
      include TSort

      def self.included(base)
        base.class_eval do
          private
          alias_method_chain :table, :schema_plus
          alias_method_chain :tables, :schema_plus
          alias_method_chain :indexes, :schema_plus
        end
      end

      private

      def tables_with_schema_plus(stream)
        @table_dumps = {}
        @re_view_referent = %r{(?:(?i)FROM|JOIN) \S*\b(#{(@connection.tables + @connection.views).join('|')})\b}
        begin
          tables_without_schema_plus(nil)

          @connection.views.each do |view_name|
            definition = @connection.view_definition(view_name)
            @table_dumps[view_name] = "  create_view #{view_name.inspect}, #{definition.inspect}\n"
          end

          tsort().each do |table|
            stream.print @table_dumps[table]
          end

        ensure
          @table_dumps = nil
        end
      end

      def tsort_each_node(&block)
        @table_dumps.keys.sort.each(&block)
      end

      def tsort_each_child(table, &block)
        references = if @connection.views.include?(table)
                       @connection.view_definition(table).scan(@re_view_referent).flatten
                     else
                       @connection.foreign_keys(table).collect(&:references_table_name)
                     end
        references.sort.uniq.each(&block)
      end

      def table_with_schema_plus(table, ignore)

        stream = StringIO.new
        table_without_schema_plus(table, stream)
        stream.rewind
        table_dump = stream.read

        if i = (table_dump =~ /^\s*[e]nd\s*$/)
          stream = StringIO.new
          foreign_keys(table, stream)
          stream.rewind
          table_dump.insert i, stream.read
        end

        @table_dumps[table] = table_dump
      end

      def indexes_with_schema_plus(table, stream)
        indexes = @connection.indexes(table)
        indexes.each do |index|
          unless index.columns.blank? 
            stream.print "  add_index #{index.table.inspect}, #{index.columns.inspect}, :name => #{index.name.inspect}"
            stream.print ", :unique => true" if index.unique
            stream.print ", :kind => \"#{index.kind}\"" unless index.kind.blank?
            stream.print ", :case_sensitive => false" unless index.case_sensitive?
            stream.print ", :conditions => #{index.conditions.inspect}" unless index.conditions.blank?
            index_lengths = index.lengths.compact if index.lengths.is_a?(Array)
            stream.print ", :length => #{Hash[*index.columns.zip(index.lengths).flatten].inspect}" if index_lengths.present?
          else
            stream.print "  add_index #{index.table.inspect}"
            stream.print ", :name => #{index.name.inspect}"
            stream.print ", :kind => \"#{index.kind}\"" unless index.kind.blank?
            stream.print ", :expression => #{index.expression.inspect}"
          end

          stream.puts
        end
        stream.puts unless indexes.empty?
      end

      def foreign_keys(table, stream)
        foreign_keys = @connection.foreign_keys(table)
        foreign_keys.each do |foreign_key|
          stream.print "  "
          stream.puts foreign_key.to_dump
        end
      end

    end
  end
end
