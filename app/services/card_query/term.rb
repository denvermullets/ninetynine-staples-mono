#
# one parsed `key:value` clause from an advanced search query
#
# `op` is normalized to one of OPS - the parser maps `:` to whichever comparison the field
# treats as its default, so handlers never have to special case the colon form.
#
module CardQuery
  Term = Struct.new(:key, :op, :value, :negated, keyword_init: true) do
    def negated? = !!negated

    # true for the operators that only make sense against a number or an ordinal
    def comparison? = %w[> >= < <=].include?(op)
  end
end
