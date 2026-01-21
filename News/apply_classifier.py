# ==================================================
# APPLY CLASSIFIER TO NEW DATA
# ==================================================
# 
# Usage:
#   1. Put your new data file (Excel/CSV) in same folder
#   2. Update INPUT_FILE and OUTPUT_FILE below
#   3. Run: python apply_classifier.py
#
# ==================================================

import pandas as pd
import numpy as np
import re
import pickle

# ==================================================
# SETTINGS - CHANGE THESE
# ==================================================

INPUT_FILE = "new_headlines.xlsx"      # Your input file
OUTPUT_FILE = "classified_output.xlsx"  # Output file
MODEL_FILE = "headline_classifier_v5.pkl"  # Model file
HEADLINE_COLUMN = "Headline"            # Column name with headlines

# ==================================================
# LOAD MODEL
# ==================================================

def tokenizer(text):
    tokens = re.findall(r"[a-zA-Z]+", text.lower())
    return [t for t in tokens if len(t) > 2]

# Category mapping
SUBCAT_TO_CAT = {
    "M&A Deal / Investment": "Corporate Actions",
    "Capital Raising": "Corporate Actions",
    "Business Plan": "Corporate Actions",
    "Product Launch / Branding / Marketing": "Corporate Actions",
    "Spin-off / Divestment": "Corporate Actions",
    "Investor Relations / Events": "Corporate Actions",
    "Partnership / Alliance": "Corporate Actions",
    "Earnings": "Performance / Earnings / Valuation",
    "Stock Performance": "Performance / Earnings / Valuation",
    "Rating / Valuation": "Performance / Earnings / Valuation",
    "Analysis Report": "Performance / Earnings / Valuation",
    "Valuation": "Performance / Earnings / Valuation",
    "Executive Appointment": "Organization / Personnel",
    "Key Personnel Departure": "Organization / Personnel",
    "Board Change": "Organization / Personnel",
    "Settlement / Penalty": "Regulatory / Legal / Compliance",
    "Regulatory Action": "Regulatory / Legal / Compliance",
    "Trial / Lawsuit": "Regulatory / Legal / Compliance",
    "Compliance Issue": "Regulatory / Legal / Compliance",
    "Macro Data": "Econ / Market Impact",
    "Central Bank": "Econ / Market Impact",
    "Policy": "Econ / Market Impact",
}

# Keywords for rare classes
KEYWORDS = {
    "Settlement / Penalty": ["settlement", "settle", "settled", "fine", "fined", "penalty", "agreed to pay"],
    "Regulatory Action": ["regulatory", "investigation", "probe", "sec ", "fca ", "fda", "antitrust", "approval"],
    "Trial / Lawsuit": ["lawsuit", "court", "litigation", "sues", "sued", "class action", "verdict", "trial"],
    "Compliance Issue": ["compliance", "violation", "breach", "misconduct", "whistleblower", "fraud"],
    "Key Personnel Departure": ["resign", "resigns", "resigned", "steps down", "departure", "leaves", "fired", "ousted"],
    "Board Change": ["board of directors", "board member", "board seat", "director appointed"],
    "Investor Relations / Events": ["investor day", "investor conference", "analyst day", "shareholder meeting"],
    "Partnership / Alliance": ["partnership", "partner", "partners", "alliance", "joint venture", "team up"],
    "Spin-off / Divestment": ["spin-off", "spinoff", "divest", "divestment", "sells unit"],
    "Macro Data": ["inflation", "cpi", "gdp", "unemployment", "payrolls", "economic data"],
    "Policy": ["government policy", "legislation", "tax reform", "tariff", "sanctions"],
    "Valuation": ["valuation", "valued at", "market cap", "enterprise value", "fair value"],
}

def keyword_predict(headline, keyword_classes):
    """Predict using keywords"""
    text_lower = headline.lower()
    best_class, best_score = None, 0
    
    for subcat, keywords in KEYWORDS.items():
        if subcat not in keyword_classes:
            continue
        matches = sum(1 for kw in keywords if kw in text_lower)
        if matches > best_score:
            best_score = matches
            best_class = subcat
    
    return best_class, best_score

def load_model(filepath):
    """Load the trained model"""
    with open(filepath, 'rb') as f:
        data = pickle.load(f)
    return data

def predict(headlines, model_data):
    """
    Predict using HYBRID approach:
    - ML for classes with >= 15 training samples
    - Keywords for classes with < 15 training samples
    """
    vectorizer = model_data['vectorizer']
    model = model_data['model']
    ml_classes = model_data['ml_classes']
    keyword_classes = model_data['keyword_classes']
    confidence_threshold = model_data.get('confidence_threshold', 0.4)
    
    # ML predictions
    X = vectorizer.transform(headlines)
    ml_preds = model.predict(X)
    ml_decisions = model.decision_function(X)
    ml_conf = 1 / (1 + np.exp(-np.max(np.abs(ml_decisions), axis=1)))
    
    results = []
    for i, headline in enumerate(headlines):
        ml_pred = ml_preds[i]
        conf = float(ml_conf[i])
        
        # Keyword prediction for rare classes
        kw_pred, kw_score = keyword_predict(headline, keyword_classes)
        
        # HYBRID LOGIC:
        # - If keyword matches a rare class strongly → use keywords
        # - Otherwise → use ML
        if kw_pred and kw_score >= 1:
            final_pred = kw_pred
            final_conf = min(kw_score / 2, 1.0)
            method = 'keywords'
        else:
            final_pred = ml_pred
            final_conf = conf
            method = 'ml'
        
        # Get category
        category = SUBCAT_TO_CAT.get(final_pred, 'Uncertain')
        
        # Check confidence
        is_confident = final_conf >= confidence_threshold
        
        results.append({
            'Predicted_Category': category if is_confident else 'Uncertain',
            'Predicted_Subcategory': final_pred if is_confident else 'Uncertain',
            'Confidence': round(final_conf, 3),
            'Method': method,
            'ML_Prediction': ml_pred,
            'ML_Confidence': round(conf, 3),
            'KW_Prediction': kw_pred if kw_pred else '',
            'KW_Score': kw_score,
        })
    
    return results


# ==================================================
# MAIN
# ==================================================

if __name__ == "__main__":
    print("="*60)
    print("  HEADLINE CLASSIFIER")
    print("="*60)
    
    # Load model
    print(f"\n1. Loading model: {MODEL_FILE}")
    try:
        model_data = load_model(MODEL_FILE)
        print(f"   ✓ Model loaded")
        print(f"   ML classes: {len(model_data['ml_classes'])}")
        print(f"   Keyword classes: {len(model_data['keyword_classes'])}")
    except FileNotFoundError:
        print(f"   ✗ ERROR: Model file not found: {MODEL_FILE}")
        print(f"   Make sure the .pkl file is in the same folder")
        exit(1)
    
    # Load input data
    print(f"\n2. Loading data: {INPUT_FILE}")
    try:
        if INPUT_FILE.endswith('.csv'):
            df = pd.read_csv(INPUT_FILE)
        else:
            df = pd.read_excel(INPUT_FILE)
        print(f"   ✓ Loaded {len(df)} rows")
    except FileNotFoundError:
        print(f"   ✗ ERROR: Input file not found: {INPUT_FILE}")
        exit(1)
    
    # Check column exists
    if HEADLINE_COLUMN not in df.columns:
        print(f"   ✗ ERROR: Column '{HEADLINE_COLUMN}' not found")
        print(f"   Available columns: {list(df.columns)}")
        exit(1)
    
    # Predict
    print(f"\n3. Classifying {len(df)} headlines...")
    headlines = df[HEADLINE_COLUMN].fillna('').tolist()
    results = predict(headlines, model_data)
    
    # Add results to dataframe
    for key in results[0].keys():
        df[key] = [r[key] for r in results]
    
    # Save output
    print(f"\n4. Saving results: {OUTPUT_FILE}")
    if OUTPUT_FILE.endswith('.csv'):
        df.to_csv(OUTPUT_FILE, index=False)
    else:
        df.to_excel(OUTPUT_FILE, index=False)
    print(f"   ✓ Saved {len(df)} rows")
    
    # Summary
    print(f"\n" + "="*60)
    print("  SUMMARY")
    print("="*60)
    
    method_counts = pd.Series([r['Method'] for r in results]).value_counts()
    print(f"\n  By Method:")
    for method, count in method_counts.items():
        print(f"    {method}: {count} ({count/len(results)*100:.1f}%)")
    
    cat_counts = pd.Series([r['Predicted_Category'] for r in results]).value_counts()
    print(f"\n  By Category:")
    for cat, count in cat_counts.head(10).items():
        print(f"    {cat}: {count}")
    
    subcat_counts = pd.Series([r['Predicted_Subcategory'] for r in results]).value_counts()
    print(f"\n  By Subcategory (top 10):")
    for subcat, count in subcat_counts.head(10).items():
        print(f"    {subcat}: {count}")
    
    print(f"\n  ✓ Done! Check {OUTPUT_FILE}")
