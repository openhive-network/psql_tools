#include "include/relation.hpp"

#include "include/exceptions.hpp"
#include "include/postgres_includes.hpp"
#include "include/tuple_fields_iterators.hpp"

#include <cassert>


using namespace std::string_literals;

namespace ForkExtension {
Relation::Relation( RelationData& _relation )
  : m_relation( _relation ) {
}

std::string binary_value_to_text( uint8_t* _value, uint32_t _size, const TupleDesc& _tuple_desc, uint16_t _column_id ) {
  Oid binary_in_func_id;
  Oid params_id;
  Form_pg_attribute attr = TupleDescAttr(_tuple_desc, _column_id );
  getTypeBinaryInputInfo( attr->atttypid, &binary_in_func_id, &params_id );
  FmgrInfo function;
  fmgr_info( binary_in_func_id, &function );

  StringInfo buffer = makeStringInfo();
  appendBinaryStringInfo( buffer, reinterpret_cast<char*>(_value), _size );

  // Here we back from binary value to value
  Datum value = ReceiveFunctionCall(&function, buffer, params_id, attr->atttypmod);

  // Now is time to get string value
  Oid out_function_id;
  bool is_varlen( false );
  getTypeOutputInfo( attr->atttypid, &out_function_id, &is_varlen );
  char* output_bytes = OidOutputFunctionCall( out_function_id, value );

  //if ( output_bytes == nullptr )
  //  THROW_RUNTIME_ERROR( "Null values in PKey columns is not supported" );

  return output_bytes;
}


Relation::PrimaryKeyColumns
Relation::getPrimaryKeysColumns() const {
  PrimaryKeyColumns result;

  Oid pkey_oid;
  auto columns_bitmap = get_primary_key_attnos( m_relation.get().rd_id, true, &pkey_oid );

  if ( columns_bitmap == nullptr ) {
    return result;
  }

  int32_t column = -1;
  while( (column = bms_next_member( columns_bitmap, column ) ) >= 0 ) {
    result.push_back( column + FirstLowInvalidHeapAttributeNumber );
  }
  return result;
}

ColumnsIterator
Relation::getColumns() const {
  return ColumnsIterator( *m_relation.get().rd_att );
}

template< typename _JavaLikeIterator >
auto moveIteratorForward( _JavaLikeIterator& _it, uint32_t _number_of_steps ) {
  decltype( _it.next() ) result;
  for ( auto step = 0u; step < _number_of_steps; ++step )
    result = _it.next();

  return result;
}

std::string
Relation::createPkeyCondition( bytea* _relation_tuple_in_copy_format ) const {
  auto sorted_primary_keys_columns = getPrimaryKeysColumns();
  auto columns_it = getColumns();
  TuplesFieldIterator tuples_fields_it(_relation_tuple_in_copy_format );

  std::string result;
  uint32_t previous_column = 0;
  for ( auto pkey_column_id : sorted_primary_keys_columns ) {
    assert( previous_column <= pkey_column_id && "Pkey columns must be sorted" );

    auto column_name_value = moveIteratorForward( columns_it, pkey_column_id - previous_column );
    assert( column_name_value && "Incosistency between primary keys columns and list of columns" );

    auto field_value = moveIteratorForward( tuples_fields_it, pkey_column_id - previous_column );
    if ( !field_value ) {
      THROW_RUNTIME_ERROR( "Incorrect tuple format" );
    }

    auto value = binary_value_to_text(  field_value.getValue(), field_value.getSize(), m_relation.get().rd_att, pkey_column_id - 1 );
    result.append( " "s + *column_name_value + "="s + value ); //TODO: change value to text

    previous_column = pkey_column_id;
  }

  return result;

}


} // namespace ForkExtension
