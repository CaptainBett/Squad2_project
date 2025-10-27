# tools/plot_athena_results.py
import sys
import pandas as pd
import matplotlib.pyplot as plt

def plot_counts(csv_path):
    df = pd.read_csv(csv_path)
    # If Athena result has header columns in first row, pandas will parse them correctly.
    print(df.head())

    # If table is event_type,total
    if 'event_type' in df.columns and 'total' in df.columns:
        df_sorted = df.sort_values('total', ascending=True)
        plt.figure(figsize=(8,6))
        plt.barh(df_sorted['event_type'], df_sorted['total'])
        plt.title('Event counts by type')
        plt.xlabel('Count')
        plt.tight_layout()
        plt.savefig("athena_plot.png", bbox_inches='tight')
        print("Saved athena_plot.png")
    elif 'item_id' in df.columns and 'views' in df.columns:
        df_sorted = df.sort_values('views', ascending=True).tail(20)
        plt.figure(figsize=(10,6))
        plt.barh(df_sorted['item_id'], df_sorted['views'])
        plt.title('Top viewed items')
        plt.xlabel('Views')
        plt.tight_layout()
        plt.savefig("athena_plot.png", bbox_inches='tight')
        print("Saved athena_plot.png")
    else:
        # generic display
        print("Columns:", df.columns)
        print(df)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python tools/plot_athena_results.py <path-to-csv>")
        sys.exit(1)
    csv_path = sys.argv[1]
    plot_counts(csv_path)
