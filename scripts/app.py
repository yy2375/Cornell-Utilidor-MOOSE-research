import streamlit as st
import jax
import jax.numpy as jnp
import equinox as eqx
import numpy as np
import joblib
import plotly.graph_objects as go
from scipy.optimize import minimize

# ==========================================
# 1. NEURAL NETWORK ARCHITECTURE
# ==========================================
class UtilidorModel(eqx.Module):
    layers: list

    def __init__(self, in_size, out_size, key):
        keys = jax.random.split(key, 5) 
        self.layers = [
            eqx.nn.Linear(in_size, 192, key=keys[0]), 
            eqx.nn.Linear(192, 192, key=keys[1]),     
            eqx.nn.Linear(192, 192, key=keys[2]),     
            eqx.nn.Linear(192, 192, key=keys[3]),     
            eqx.nn.Linear(192, out_size, key=keys[4]) 
        ]

    def __call__(self, x):
        for layer in self.layers[:-1]:
            x = jax.nn.gelu(layer(x))
        return self.layers[-1](x)

# ==========================================
# 2. CACHE INFRASTRUCTURE & HELPERS
# ==========================================
@st.cache_resource
def load_infrastructure():
    skeleton_model = UtilidorModel(8, 32, jax.random.PRNGKey(0))
    loaded_model = eqx.tree_deserialise_leaves("utilidor_model (4).eqx", skeleton_model)
    scaler_X = joblib.load("scaler_X (4).pkl")
    scaler_Y = joblib.load("scaler_Y (4).pkl")
    return loaded_model, scaler_X, scaler_Y

model, scaler_X, scaler_Y = load_infrastructure()

def predict_scenario(inputs):
    new_inputs_np = np.array([inputs], dtype=float)
    new_inputs_np[0, 0] = np.log10(new_inputs_np[0, 0]) 
    inputs_scaled = scaler_X.transform(new_inputs_np)
    prediction_scaled = model(jnp.array(inputs_scaled[0]))
    prediction_unscaled = scaler_Y.inverse_transform([prediction_scaled])
    return prediction_unscaled[0]

def plot_geometry(depth, a, b, title="Utilidor Cross-Section"):
    y_center = -(depth + b)
    fig = go.Figure()
    fig.add_shape(type="line", x0=-15, x1=15, y0=0, y1=0, line=dict(color="green", width=3))
    t = np.linspace(0, 2*np.pi, 100)
    fig.add_trace(go.Scatter(x=a*np.cos(t), y=y_center + b*np.sin(t), 
                             mode='lines', line=dict(color='blue', width=2), name="Wall"))
    nodes_x = [0, 0, a, -a]
    nodes_y = [y_center+b, y_center-b, y_center, y_center]
    fig.add_trace(go.Scatter(x=nodes_x, y=nodes_y, mode='markers', marker=dict(color='red', size=10)))
    fig.update_layout(title=title, xaxis_title="Distance (m)", yaxis_title="Depth (m)",
                      yaxis=dict(scaleanchor="x", scaleratio=1), showlegend=False, height=400)
    return fig

# ==========================================
# 3. WEB INTERFACE
# ==========================================
st.set_page_config(layout="wide")
st.title("Subterranean Utilidor Design & Optimization")

# Sidebar: Environment & Safety
st.sidebar.header("Geomechanical Environment")
E_val = st.sidebar.number_input("Young's Modulus (Pa)", value=3.6e10, format="%.2e")
nu_val = st.sidebar.slider("Poisson's Ratio", 0.1, 0.45, 0.128)
gamma_val = st.sidebar.number_input("Unit Weight (N/m³)", value=24000.0)
K_val = st.sidebar.slider("Lateral Confinement (K)", 0.5, 2.0, 1.5)
depth_val = st.sidebar.slider("Crown Depth (m)", 1.5, 15.0, 8.0)
top_load_val = st.sidebar.number_input("Surface Surcharge (Pa)", value=10000.0, format="%.1e")

st.sidebar.header("Design Safety Limits")
# NEW: Maximum Allowable Stress Input
max_stress_limit = st.sidebar.number_input("Max Allowable Stress (Pa)", value=1.0e6, format="%.1e")

# ------------------------------------------
# MODE 1: FORWARD PREDICTION
# ------------------------------------------
st.header("1. Forward Prediction")
main_col, warn_col = st.columns([3, 1]) # Right side warning column

with main_col:
    c1, c2 = st.columns(2)
    a_in = c1.number_input("Semi-Major Axis (a)", value=1.89)
    b_in = c2.number_input("Semi-Minor Axis (b)", value=1.55)

if st.button("Predict State"):
    inputs = [E_val, nu_val, gamma_val, K_val, depth_val, a_in, b_in, top_load_val]
    preds = predict_scenario(inputs)
    
    # Calculate Max Stress Magnitude at Corners
    # Indices: 2 (Top XX), 10 (Bot XX), 19 (Right YY), 27 (Left YY)
    corner_stresses = [preds[2], preds[10], preds[19], preds[27]]
    max_calc_stress = np.max(np.abs(corner_stresses))

    with main_col:
        st.plotly_chart(plot_geometry(depth_val, a_in, b_in), use_container_width=True)
        st.subheader("Metric Summary")
        m1, m2, m3 = st.columns(3)
        m1.metric("Max Node Stress", f"{max_calc_stress/1e6:.3f} MPa")
        m2.metric("Top Settlement", f"{preds[1]*1000:.3f} mm")
        m3.metric("Invert Rebound", f"{preds[9]*1000:.3f} mm")

    # NEW: Logic for warning on the right side
    with warn_col:
        st.write("### Safety Status")
        if max_calc_stress > max_stress_limit:
            st.error(f"⚠️ EXCEEDS LIMIT\n\nStress of {max_calc_stress/1e6:.2f} MPa exceeds the {max_stress_limit/1e6:.2f} MPa allowable threshold.")
        else:
            st.success("✅ WITHIN LIMITS")

st.divider()

# ------------------------------------------
# MODE 2: AI SHAPE OPTIMIZATION
# ------------------------------------------
st.header("2. AI Shape Optimization (SLSQP)")
target_area = st.number_input("Target Cross-Sectional Area (m²)", value=15.0)

if st.button("Run Multi-Start Optimization"):
    with st.spinner("Executing SLSQP Optimizer..."):
        def area_constraint(x):
            return (np.pi * x[0] * x[1]) - target_area 

        def objective_function(x):
            inputs = [E_val, nu_val, gamma_val, K_val, depth_val, x[0], x[1], top_load_val]
            predictions = predict_scenario(inputs)
            return np.max(np.abs([predictions[2], predictions[10], predictions[19], predictions[27]]))

        bounds = [(0.5, 5.0), (0.5, 5.0)]
        cons = {'type': 'eq', 'fun': area_constraint}
        initial_guesses = [[2.18, 2.18], [1.0, 4.77], [4.77, 1.0]]
        
        best_result = None
        lowest_stress = float('inf')
        
        for guess in initial_guesses:
            result = minimize(objective_function, guess, method='SLSQP', bounds=bounds, constraints=cons)
            if result.success and result.fun < lowest_stress:
                lowest_stress = result.fun
                best_result = result
        
        if best_result is not None:
            opt_a, opt_b = best_result.x
            st.success(f"Optimization Converged at {best_result.fun/1e6:.3f} MPa.")
            
            # Use the same dual-column layout for optimization results
            opt_main, opt_warn = st.columns([3, 1])
            with opt_main:
                st.plotly_chart(plot_geometry(depth_val, opt_a, opt_b, "Optimized Geometry"), use_container_width=True)
            
            with opt_warn:
                st.write("### Optimized Safety")
                if best_result.fun > max_stress_limit:
                    st.warning("⚠️ CRITICAL: Even the optimized shape exceeds the allowable stress limit for this environment.")
                else:
                    st.success("✅ OPTIMIZED: Shape meets all safety requirements.")