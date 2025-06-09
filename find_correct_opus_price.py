#!/usr/bin/env python3

# Calculate what Opus pricing would result in the correct total cost
# We know:
# - ccusage shows $521.19 total
# - We have 1012 Opus entries and 1298 Sonnet entries
# - Sonnet pricing is correct ($3/$15 per million tokens)

# Estimate based on the cost difference
total_cost_ccusage = 521.19
app_shows = 668.00
difference = app_shows - total_cost_ccusage

print(f"Cost difference: ${difference:.2f}")
print("\nIf we assume Sonnet entries are priced correctly,")
print("then the extra ${:.2f} must come from Opus mispricing.".format(difference))
print("\nWith 1012 Opus entries, that's ~${:.2f} extra per Opus entry".format(difference/1012))
print("\nThis suggests our Opus pricing might be too high.")
print("\nLet's check if Opus should be priced the SAME as Sonnet...")

# If Opus was same price as Sonnet, the total would match ccusage
print("\n💡 Hypothesis: claude-opus-4 and claude-sonnet-4 might have the SAME pricing!")
print("   This would explain why ccusage shows ~$521")